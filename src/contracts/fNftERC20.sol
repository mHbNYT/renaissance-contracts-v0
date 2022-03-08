//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {FNFTController} from "./FNFTController.sol";
import "../test/utils/console.sol";

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
    event FNFTCreated(address nft, uint256 tokenId, address creator, uint256 fractions);

    /// @notice emitted when someone holding >5% of the total supply creates a proposal to increase the vote
    /// @param newPrice the new reserve price in ETH
    event ReservePriceUpdated(uint256 newPrice);

    /// @notice emitted when a bid is placed on the nft, bids must be in place in ETH
    /// @param proposer the address of the proposer
    /// @param proposedPrice the new reserve price in ETH
    /// @param createdBlock blockNumber the proposal was created on
    event ReserveChangeProposalCreated(address indexed proposer, uint256 proposedPrice, uint256 createdBlock);

    event Vote(address indexed voter, uint256 voteAmount);

    /// @notice emitted when a bid is placed on the nft, bids must be in place in ETH
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    /// @param expiraryBlock block number the bid expires on
    event Bid(address bidder, uint256 amount, uint256 expiraryBlock);

    /// @notice emitted when a bid is withdrawn
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    event BidWithdrawn(address bidder, uint256 amount);

    /// @notice emitted when a bid is withdrawn
    /// @param liquidator the address of the user who liquidated the NFT
    event Liquidated(address liquidator);

    /// @notice emitted when a user's tokens are redeemed proportionally for the sale amount
    /// @param user the user's tokens
    event TokensRedeemed(address user, uint256 amount);

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

    error WithdrawingHighestBid();
    error NFTLiquidated();
    error NFTNotSold();
    error CannotRefractionalize();
    error TokenRedemptionFail();
    error ZeroAddress();
    error BidWithdrawalFail();
    error BidAlreadyPlaced();
    error BidDoesntExist();
    error BidTooSmall();
    error IncorrectNFTAddress();
    error IncorrectTokenId();
    error AuctionNotOver();
    error AuctionAccepted();
    error ProposalInProgress();
    error ProposalExpired();
    error NotHighestBidder();
    error NotEnoughTokens();
    error NotEnoughVotes();

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier unlocked() {
        // if the contract doesn't have an NFT then the token has been liquidated
        if (!contractHasNFT) revert NFTLiquidated();
        _;
    }

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/
    ERC721 public nft;
    uint256 public tokenId;
    address public creator;
    uint256 public reservePrice;
    bool public contractHasNFT;
    bool public initializing = true;

    ReserveChangeProposal public reserveUpdateProposal;
    HighestBid public highestBid;
    mapping(address => uint256) public bids;

    FNFTController public controller;

    /// @param _nft the contract address of the underlying NFT
    /// @param _tokenId the tokenId of the underlying NFT
    /// @param _fractions the amount of fractions to create
    /// @param _reservePrice the reserve price needed to liquidate the nft
    constructor(
        address _owner,
        address _nft,
        uint256 _tokenId,
        uint224 _fractions,
        uint256 _reservePrice,
        FNFTController _FNFTController
    )
        ERC20(
            string(abi.encodePacked("Fractionalized ", ERC721(_nft).name())),
            string(abi.encodePacked("fNFT-", ERC721(_nft).symbol(), "-#", Strings.toString(_tokenId)))
        )
        ERC20Permit(string(abi.encodePacked("Fractionalized ", ERC721(_nft).name())))
    {
        if (_owner == address(0)) revert ZeroAddress();
        nft = ERC721(_nft);
        tokenId = _tokenId;
        reservePrice = _reservePrice;
        controller = _FNFTController;

        emit FNFTCreated(address(_nft), tokenId, msg.sender, _fractions);

        _mint(_owner, _fractions);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the user to place a bid on an NFT with an expiraryBlock date.
    ///     bids are placed in eth and held by this contract until the expiraryBlock.
    /// NOTE: cannot be used to increase a bid
    function placeBid() external payable unlocked {
        //TODO: make sure there is not reserve price increase vote in progress
        if (bids[msg.sender] > 0) revert BidAlreadyPlaced();
        if (msg.value < reservePrice || msg.value <= highestBid.amount) revert BidTooSmall();

        highestBid.expiraryBlock = controller.getBidExpirary(highestBid.amount == 0);
        highestBid.bidder = msg.sender;
        highestBid.amount = msg.value;

        bids[msg.sender] = msg.value;

        emit Bid(msg.sender, msg.value, highestBid.expiraryBlock);
    }

    /// @notice allows a user to increase their bid by msg.value amount
    function increaseBid() external payable unlocked {
        //TODO: make sure there is not reserve price increase vote in progress
        uint256 newBid = bids[msg.sender] + msg.value;
        if (bids[msg.sender] == 0) revert BidDoesntExist();
        if (newBid < reservePrice || newBid <= highestBid.amount) revert BidTooSmall();

        highestBid.expiraryBlock = controller.getBidExpirary(false);
        highestBid.bidder = msg.sender;
        highestBid.amount = newBid;

        bids[msg.sender] = newBid;

        emit Bid(msg.sender, newBid, highestBid.expiraryBlock);
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

    function withdrawNFT() external unlocked {
        if (highestBid.bidder != msg.sender) revert NotHighestBidder();
        if (highestBid.expiraryBlock < block.number) revert AuctionNotOver();

        contractHasNFT = false;
        delete bids[msg.sender];

        emit Liquidated(msg.sender);

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    /// @notice Allows the user to unfractionalize if they own 100% of the total supply (all fractions)
    function unfractionalizeWithAllTokens() external unlocked {
        if (balanceOf(msg.sender) < totalSupply()) revert NotEnoughTokens();

        contractHasNFT = false;
        emit Liquidated(msg.sender);

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function createReserveChangeProposal(uint256 _newReserve) external unlocked {
        // if the contract doesn't have an accepted bid
        if (highestBid.expiraryBlock != 0 && highestBid.expiraryBlock < block.number) revert AuctionAccepted();
        // if the contract doesn't already have a reserve change proposal and it's not expired
        if (
            reserveUpdateProposal.createdBlock != 0 &&
            getProposalExpirary(reserveUpdateProposal.createdBlock) > block.number //TODO: check to see if it reached quorum
        ) revert ProposalInProgress();
        // must hold at least 5% of the total supply in order to call a reverse increase proposal
        if ((balanceOf(msg.sender) * 100) / totalSupply() < 5)
            //
            revert NotEnoughTokens();

        reserveUpdateProposal = ReserveChangeProposal({
            proposer: msg.sender,
            reservePrice: _newReserve,
            votesInFavor: getVotes(msg.sender),
            createdBlock: block.number - 1
        });

        emit ReserveChangeProposalCreated(msg.sender, _newReserve, block.number);
    }

    function voteInFavor() external unlocked {
        if (
            reserveUpdateProposal.createdBlock != 0 &&
            getProposalExpirary(reserveUpdateProposal.createdBlock) < block.number
        ) revert ProposalExpired();

        uint256 votingPower = getPastVotes(msg.sender, reserveUpdateProposal.createdBlock);

        reserveUpdateProposal.votesInFavor += votingPower;

        emit Vote(msg.sender, votingPower);
    }

    function updateReservePrice() external unlocked {
        if ((reserveUpdateProposal.votesInFavor * 100) / totalSupply() < controller.quorumPercentage())
            revert NotEnoughVotes();

        uint256 newPrice = reserveUpdateProposal.reservePrice;
        reservePrice = newPrice;
        delete reserveUpdateProposal;

        emit ReservePriceUpdated(newPrice);
    }

    function redeemTokensForETH() external {
        bool bidAccepted = !contractHasNFT && highestBid.expiraryBlock < block.number;
        if (!bidAccepted) revert NFTNotSold();

        uint256 userBalance = balanceOf(msg.sender);
        uint256 shareOwed = (highestBid.amount * ((userBalance * 100) / totalSupply())) / 100;
        transferFrom(msg.sender, address(this), userBalance);
        emit TokensRedeemed(msg.sender, shareOwed);

        (bool success, ) = msg.sender.call{value: shareOwed}("");
        if (!success) revert TokenRedemptionFail();
    }

    /*///////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getProposalExpirary(uint256 _blockNum) public view returns (uint256) {
        return _blockNum + (controller.proposalExpiraryHours() * controller.blocksPerHour());
    }

    // needs to only work after contract creation, but before initialization
    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes memory
    ) public override returns (bytes4) {
        if (!initializing) revert CannotRefractionalize();
        if (msg.sender != address(nft)) revert IncorrectNFTAddress();
        if (_tokenId != tokenId) revert IncorrectTokenId();
        initializing = false;
        contractHasNFT = true;
        creator = _from;
        return this.onERC721Received.selector;
    }

    // for testing
    function getBlockNum() public view returns (uint256) {
        return block.number;
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

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
