//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "@openzeppelin/contracts/utils/Strings.sol";

/// @title FNFTERC20
/// @author @0xlucky @0xsoon @colinnielsen
/// @notice ERC20 contract for RenaissanceLab's NFT fractionalization protocol
/// @dev An ERC20 token represented by an underlying asset NFT, has a built-in redemption and bid mechanism

contract FNFTERC20 is ERC20, ERC721Holder, ERC20Votes {
    /*///////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an FNFT is created
    /// @param nft the address of the nft contract
    /// @param tokenId the token id of the individual nft
    /// @param creator the creator (fractionalizer) of the nft
    /// @param fractions the totalSupply of the erc20
    event FNFTCreated(
        address nft,
        uint256 tokenId,
        address creator,
        uint256 fractions
    );

    /// @notice emitted when a bid is placed on the nft, bids must be in place in ETH
    /// @param proposer the address of the proposer
    /// @param newReserve the new reserve price in ETH
    /// @param createdBlock blockNumber the proposal was created on
    event ReserveChangeProposalCreated(
        address indexed proposer,
        uint256 newReserve,
        uint256 createdBlock
    );

    event Vote(address indexed voter, uint256 voteAmount);

    /// @notice emitted when a bid is placed on the nft, bids must be in place in ETH
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    /// @param expiraryBlock block number the bid expires on
    event BidCreated(address bidder, uint256 amount, uint256 expiraryBlock);

    /// @notice emitted when a bid is withdrawn
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    event BidWithdrawn(address bidder, uint256 amount);

    /// @notice emitted when a bid is withdrawn
    /// @param liquidator the address of the user who liquidated the NFT
    event Liquidated(address liquidator);

    /*///////////////////////////////////////////////////////////////
                             STRUCTS / ENUMS
    //////////////////////////////////////////////////////////////*/
    struct HighestBid {
        address bidder;
        uint256 expiraryBlock;
        uint256 amount;
    }

    struct ReserveChangeProposal {
        address proposer;
        uint256 reservePrice;
        uint256 votesInFavor;
        uint256 createdBlock;
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    error ThresholdTooHigh();
    error BidAccepted();
    error ZeroBid();
    error BadExpirary();
    error BidNotExpired();
    error BidWithdrawalFail();
    error WithdrawingHighestBid();
    error NotHighestBidder();
    error BidDoesntExist();
    error IncorrectNFT();
    error IncorrectTokenId();
    error AuctionNotOver();
    error AlreadyHasNFT();
    error AuctionAccepted();
    error BidTooSmall();
    error NFTLiquidated();
    error PayoutTooSmall();
    error ProposalInProgress();
    error ProposalExpired();
    error NotEnoughTokens();

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC721 public nft;
    uint256 public tokenId;
    address public creator;
    uint256 public bidThreshold;
    uint256 public reservePrice;
    bool public contractHasNFT;

    ReserveChangeProposal public reserveChangeProposal;
    HighestBid public highestBid;
    mapping(address => uint256) public bids;

    uint256 public immutable BLOCKS_PER_DAY; //72k for aurora @ avg 1.2s block time
    uint256 public constant QUORUM_PERCENTAGE = 50; //50%

    /// @param _nft the contract address of the underlying NFT
    /// @param _tokenId the tokenId of the underlying NFT
    /// @param _fractions the amount of fractions to create
    /// @param _reservePrice the reserve price needed to liquidate the nft
    constructor(
        ERC721 _nft,
        uint256 _tokenId,
        uint256 _fractions,
        uint256 _reservePrice,
        uint256 _blocksPerDay
    )
        ERC20(
            string(abi.encodePacked("Fractionalized ", _nft.name())),
            string(
                abi.encodePacked(
                    "fNFT-",
                    _nft.symbol(),
                    "-#",
                    Strings.toString(_tokenId)
                )
            )
        )
        ERC20Permit(string(abi.encodePacked("Fractionalized ", _nft.name())))
    {
        nft = _nft;
        tokenId = _tokenId;
        reservePrice = _reservePrice;
        BLOCKS_PER_DAY = _blocksPerDay;

        emit FNFTCreated(address(_nft), tokenId, msg.sender, _fractions);

        _mint(msg.sender, _fractions);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the user to place a bid on an NFT with an expiraryBlock date.
    ///     bids are placed in eth and held by this contract until the expiraryBlock.
    ///     NOTE: If you have been outbid, you can increase your bid here.
    function placeBid() external payable {
        uint256 bidValue = bids[msg.sender] += msg.value;

        if (contractHasNFT) revert NFTLiquidated();
        if (bidValue < reservePrice || bidValue < highestBid.amount)
            revert BidTooSmall();

        highestBid.expiraryBlock =
            block.number +
            (BLOCKS_PER_DAY * (highestBid.amount == 0 ? 7 : 1)); // initial bid has a cooldown of 7 days, bid war extends the expiraryBlock by 1 day,
        highestBid.bidder = msg.sender;
        highestBid.amount = bidValue;

        bids[msg.sender] = bidValue;

        emit BidCreated(msg.sender, msg.value, highestBid.expiraryBlock);
    }

    /// @notice allows the user to withdrawal their losing bid
    function withdrawBid() external {
        // prevent a user from withdrawing a bid when their bid is the highest bid
        // NOTE: this should imply that you can't withdraw if you've won
        if (highestBid.bidder == msg.sender) revert WithdrawingHighestBid();

        uint256 paybackAmount = bids[msg.sender];

        // delete their bid info
        delete bids[msg.sender];

        emit BidWithdrawn(msg.sender, paybackAmount);

        // send it back to the user and require the transfer succeeds
        (bool success, ) = msg.sender.call{value: paybackAmount}("");
        if (!success) revert BidWithdrawalFail();
    }

    function withdrawNFT() external {
        if (!contractHasNFT) revert NFTLiquidated();
        if (highestBid.bidder != msg.sender) revert NotHighestBidder();
        if (highestBid.expiraryBlock < block.number) revert AuctionNotOver();

        contractHasNFT = false;
        emit Liquidated(msg.sender);

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @notice Allows the user to unfractionalize if they own 100% of the total supply (all fractions)
    function unfractionalizeWithAllTokens() external {
        if (balanceOf(msg.sender) < totalSupply()) revert NotEnoughTokens();

        contractHasNFT = false;
        emit Liquidated(msg.sender);

        ERC721(nft).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function createReserveChangeProposal(uint256 _newReserve) external {
        if (!contractHasNFT) revert NFTLiquidated();
        if (
            highestBid.expiraryBlock != 0 &&
            highestBid.expiraryBlock < block.number
        ) revert AuctionAccepted();
        if (
            reserveChangeProposal.createdBlock != 0 &&
            getProposalExpirary(reserveChangeProposal.createdBlock) >
            block.number
        ) revert ProposalInProgress();
        if ((balanceOf(msg.sender) * 100) / totalSupply() < 5)
            revert NotEnoughTokens(); // must hold at least 5% of the total supply in order to call a reverse increase proposal

        reserveChangeProposal = ReserveChangeProposal({
            proposer: msg.sender,
            reservePrice: _newReserve,
            votesInFavor: 0,
            createdBlock: block.number
        });

        emit ReserveChangeProposalCreated(
            msg.sender,
            _newReserve,
            block.number
        );
    }

    function voteInFavor() external {
        if (!contractHasNFT) revert NFTLiquidated();
        if (
            reserveChangeProposal.createdBlock != 0 &&
            getProposalExpirary(reserveChangeProposal.createdBlock) <
            block.number
        ) revert ProposalExpired();

        uint256 votingPower = getPastVotes(
            msg.sender,
            reserveChangeProposal.createdBlock
        );

        reserveChangeProposal.votesInFavor += votingPower;

        emit Vote(msg.sender, votingPower);
    }

    function changeReservePrice() external {
        if (
            (reserveChangeProposal.votesInFavor * 100) / totalSupply() <
            QUORUM_PERCENTAGE
        ) revert();
        reservePrice = reserveChangeProposal.reservePrice;
        delete reserveChangeProposal;
        // emit reserve accepted;
    }

    /*///////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getProposalExpirary(uint256 _blockNum)
        public
        view
        returns (uint256)
    {
        return _blockNum + (BLOCKS_PER_DAY * 10);
    }

    function getBlockNum() public view returns (uint256) {
        return block.number;
    }

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes memory
    ) public override returns (bytes4) {
        if (contractHasNFT) revert AlreadyHasNFT();
        if (msg.sender != address(nft)) revert IncorrectNFT();
        if (_tokenId != tokenId) revert IncorrectTokenId();
        contractHasNFT = true;
        creator = _from;
        return this.onERC721Received.selector;
    }

    /*///////////////////////////////////////////////////////////////
                            INTERAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
        _delegate(to, to);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
