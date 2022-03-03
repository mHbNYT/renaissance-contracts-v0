//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/// @title FNFTERC20
/// @author @0xlucky @0xsoon @colinnielsen
/// @notice ERC20 contract for RenaissanceLab's NFT fractionalization protocol
/// @dev An ERC20 token represented by an underlying asset NFT, has a built-in redemption and bid mechanism

contract FNFTERC20 is
    ERC20,
    ERC20Permit,
    ERC721Holder //, ERC20Snapshot
{
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
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    /// @param expirary timestamp of the bid
    event BidCreated(address bidder, uint256 amount, uint256 expirary);

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
        uint256 expirary;
        uint256 amount;
    }

    // struct ReserveProposal {
    //     uint256 amount;
    //     uint256 expirary;
    // }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    error ThresholdTooHigh();
    error BidAccepted();
    error ZeroBid();
    error BadExpirary();
    error BidNotExpired();
    error BidWithdrawalFail();
    error WithdrawHighestBid();
    error NotHighestBidder();
    error BidDoesntExist();
    error IncorrectNFT();
    error IncorrectTokenId();
    error AuctionNotOver();
    error AlreadyHasNFT();
    error BidTooSmall();
    error NFTLiquidated();
    error PayoutTooSmall();
    error NotEnoughTokens();
    error NoV2Pair();

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC721 public nft;
    uint256 public tokenId;
    address public creator;
    uint256 public bidThreshold;
    uint256 public reservePrice;
    bool public contractHasNFT;

    HighestBid public highestBid;
    mapping(address => uint256) public bids;

    uint256 public immutable BLOCKS_PER_DAY; //72k for aurora @ avg 1.2s block time

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
        BLOCKS_PER_DAY = _blocksPerDay;
        reservePrice = _reservePrice;
        contractHasNFT = true;
        _mint(msg.sender, _fractions);

        emit FNFTCreated(address(_nft), tokenId, msg.sender, _fractions);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the user to place a bid on an NFT with an expirary date.
    ///     bids are placed in eth and held by this contract until the expirary.
    ///     NOTE: If you have been outbid, you can increase your bid here.
    function placeBid() external payable {
        uint256 bidValue = bids[msg.sender] += msg.value;

        if (contractHasNFT) revert NFTLiquidated();
        if (bidValue < reservePrice || bidValue < highestBid.amount)
            revert BidTooSmall();

        highestBid.expirary =
            block.number +
            (BLOCKS_PER_DAY * (highestBid.amount == 0 ? 7 : 1)); // initial bid has a cooldown of 7 days, bid war extends the expirary by 1 day,
        highestBid.bidder = msg.sender;
        highestBid.amount = bidValue;

        bids[msg.sender] = bidValue;

        emit BidCreated(msg.sender, msg.value, highestBid.expirary);
    }

    /// @notice allows the user to withdrawal their losing bid after the expiraryDate has passed
    function withdrawBid() external {
        // prevent a user from withdrawing a bid when their bid is the highest bid
        // NOTE: this should imply that you can't withdraw if you've won
        if (highestBid.bidder == msg.sender) revert WithdrawHighestBid();

        uint256 amountOwed = bids[msg.sender];

        // delete their bid info
        delete bids[msg.sender];

        emit BidWithdrawn(msg.sender, amountOwed);

        // send it back to the user and require the transfer succeeds
        (bool success, ) = msg.sender.call{value: amountOwed}("");
        if (!success) revert BidWithdrawalFail();
    }

    function withdrawNFT() external {
        if (!contractHasNFT) revert NFTLiquidated();
        if (highestBid.bidder != msg.sender) revert NotHighestBidder();
        if (highestBid.expirary < block.number) revert AuctionNotOver();

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

    /*///////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    // function _beforeTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal override(ERC20, ERC20Snapshot) {}

    // function _afterTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 amount
    // ) internal override(ERC20, ERC20Votes) {}

    // function _mint(address _to, uint256 _amount)
    //     internal
    //     override(ERC20, ERC20Votes)
    // {}

    // function _burn(address account, uint256 amount)
    //     internal
    //     override(ERC20, ERC20Votes)
    // {}
}
