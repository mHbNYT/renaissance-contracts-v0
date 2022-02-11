//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

contract FNFTERC20 is ERC20, ERC721Holder {
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
    event BidCreated(address bidder, uint256 amount, uint32 expirary);

    /// @notice emitted when a bid is withdrawn
    /// @param bidder the address of the bidder
    /// @param amount of ETH
    event BidWithdrawn(address bidder, uint256 amount);

    /// @notice emitted when a bid is withdrawn
    /// @param liquidator the address of the user who liquidated the NFT
    /// @param liquidationType the type of liquidation: 0 = Redemption, 2 = Auction
    event Liquidated(address liquidator, LiquidationType liquidationType);

    /*///////////////////////////////////////////////////////////////
                             STRUCTS / ENUMS
    //////////////////////////////////////////////////////////////*/

    struct Bid {
        bool accepted;
        uint64 expirary;
        uint256 amount;
    }

    enum LiquidationType {
        Redemption,
        Auction
    }

    /*///////////////////////////////////////////////////////////////
                                  ERRORS
    //////////////////////////////////////////////////////////////*/

    error ThresholdTooHigh();
    error BidAccepted();
    error ZeroBid();
    error BadExpirary();
    error BidWithdrawalFail();
    error NFTLiquidated();
    error PayoutTooSmall();
    error NotEnoughTokens();
    error NoV2Pair();

    /*///////////////////////////////////////////////////////////////
                          IMMUTABLES / CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public immutable WETH = 0x4feab816feFD22E27e0A6a7f73211df73de3C510;
    IUniswapV2Factory public immutable factory;

    /*///////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC721 public nft;
    uint256 public tokenId;
    address public creator;
    uint256 public bidThreshold;
    uint256 public redeemThreshold;
    address public redemptionBlacklist;

    bool public liquidated;
    bool public bidAccepted;
    uint256 public highestBid;
    address public auctionWinner;

    mapping(address => Bid) public bids;

    /// @param _nft the contract address of the underlying NFT
    /// @param _tokenId the tokenId of the underlying NFT
    /// @param _fractions the amount of fractions to create
    /// @param _bidThreshold the bid acceptance threshold % necessary to accept a bid on an fNFT (e.g: 50 = 50%)
    /// @param _redeemThreshold the % of the totalSupply you have to hold to redeem the token automatically
    /// @param _redemptionBlacklist an optional address you can blacklist from the redemption process:
    ///         (e.g: if the treasury holds 50%, you may want to ignore the treasury's balance when calculating the what % of the totalSupply a redeemer needs to hold)
    constructor(
        IUniswapV2Factory _factory,
        ERC721 _nft,
        uint256 _tokenId,
        uint256 _fractions,
        uint8 _bidThreshold,
        uint8 _redeemThreshold,
        address _redemptionBlacklist
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
    {
        // revert if the redemption threshold is greater than 100%, or less than 0%
        if (_redeemThreshold > 100) revert ThresholdTooHigh();
        factory = _factory;
        nft = _nft;
        tokenId = _tokenId;
        bidThreshold = _bidThreshold;
        redeemThreshold = _redeemThreshold;
        redemptionBlacklist = _redemptionBlacklist;
        creator = msg.sender;
        _mint(msg.sender, _fractions);

        emit FNFTCreated(address(_nft), tokenId, msg.sender, _fractions);
    }

    /*///////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows the user to place a bid on an NFT with an expirary date.
    ///     bids are placed in eth and held by this contract until the expirary.
    ///     NOTE: If you have been outbid, you can increase your bid here.
    /// @param expiraryDate the expirary date of the bid
    function bid(uint32 expiraryDate) external payable {
        // @audit prevent a user from spamming bids (1 highest bid at a time) - ?

        // prevent a user from bidding when a bid is accepted
        if (bidAccepted) revert BidAccepted();
        // prevent a user from bidding 0
        if (msg.value == 0) revert ZeroBid();
        // prevent a user from placing a bid with an expirary in the past and from placing a bid with an expirary < 7 days
        if (
            expiraryDate < block.timestamp ||
            expiraryDate > block.timestamp + 7 days
        ) revert BadExpirary();

        bids[msg.sender].amount = msg.value;
        bids[msg.sender].expirary = expiraryDate;

        emit BidCreated(msg.sender, msg.value, expiraryDate);
    }

    /// @notice allows the user to withdrawal their losing bid after the expiraryDate has passed
    function withdrawalBid() external {
        // prevent a user from withdrawing a bid when a bid is accepted
        if (bids[msg.sender].accepted) revert BidAccepted();

        // delete their bid info
        delete bids[msg.sender];

        // send it back to the user and require the transfer succeeds
        (bool success, ) = msg.sender.call{value: bids[msg.sender].amount}("");
        if (!success) revert BidWithdrawalFail();

        emit BidWithdrawn(msg.sender, bids[msg.sender].amount);
    }

    /// @notice Allows a user to redeem if they hold > redeemThreshold of the totalSupply
    /// @dev User must transfer: fNFT price (in eth) * (totalSupply - balance[msg.sender]) to payout the remaining holders
    function redeem() external payable {
        uint256 userBalance = balanceOf(msg.sender);
        // ensure the user's current balance is above the redemption threshold %
        if ((userBalance * 100) / totalSupply() < redeemThreshold)
            revert NotEnoughTokens();
        // prevent a user from redeeming when a bid is accepted
        if (bidAccepted) revert BidAccepted();
        // prevent a user from redeeming when the nft has already been removed (liquidated) via redemption or auction
        if (liquidated) revert NFTLiquidated();

        // get the LP pair address of this contract and ETH from the uniswap v2 factory
        address pair = factory.getPair(address(this), WETH);

        // calc the amount the redeemer needs to pay the remaining holders
        // NOTE: if there is a blacklisted address (e.g: a treasury), then we need to ignore their balance
        // NOTE: MINIMUM_LIQUIDITY represents the small amount of tokens that are transferred to address(0) (i.e: locked forever)
        //      on the creation of a uni liquidity pool, we should not ask the redeemer to payback address(0) :)
        uint256 tokensToPayout = totalSupply() -
            (redemptionBlacklist == address(0) ? 0 : balanceOf(redemptionBlacklist)) -
            userBalance -
            IUniswapV2Pair(pair).MINIMUM_LIQUIDITY();

        // calculate the price in eth that the redeemer needs to pay the remaining holders
        uint256 payoutInEth = tokensToPayout * lastPrice();
        // ensure the amount of eth they sent matches the price of the remaining holders
        if (msg.value < payoutInEth) revert PayoutTooSmall();

        liquidated = true;

        emit Liquidated(msg.sender, LiquidationType.Redemption);
    }

    /*///////////////////////////////////////////////////////////////
                            TODO: finish funcs
    //////////////////////////////////////////////////////////////*/

    // function withdrawalReward() external;

    /// @notice allows for holders to vote on an fNFT bid
    /// @dev Bids are viewable and votable in a ratio of 1:1 (1 token = 1 bid)
    ///     if the holders vote > bid vote threshold, the user can withdrawl the underlying NFT
    ///     NOTE: In the constructor, you can opt to blacklist a certain address from the bid threshold
    // function voteApproveBid() external;

    /*///////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function lastPrice() public view returns (uint256) {
        // get the pair address from the uniswap v2 factory
        address pair = factory.getPair(address(this), WETH);

        // revert if the pair doesn't exist (e.g: the the LP hasn't been deployed yet)
        if (pair == address(0)) revert NoV2Pair();
        // sort the tokens by order so we can query the for this fNFT price in comparison to the ETH price
        (address token0, ) = address(this) < WETH
            ? (address(this), WETH)
            : (WETH, address(this));

        // if the first token is this fNFT contract, then query for that price against eth
        uint256 price = token0 == address(this)
            ? IUniswapV2Pair(pair).price0CumulativeLast()
            : IUniswapV2Pair(pair).price1CumulativeLast();
        return price;
    }
}
