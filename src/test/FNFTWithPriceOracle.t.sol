//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "ds-test/test.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {FNFTSettings} from "../contracts/FNFTSettings.sol";
import {PriceOracle, IPriceOracle, PairInfo} from "../contracts/PriceOracle.sol";
import {FNFTFactory, ERC721Holder} from "../contracts/FNFTFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IUniswapV2Pair} from "../contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Factory} from "../contracts/interfaces/IUniswapV2Factory.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {CheatCodes, SetupEnvironment, User, Curator, UserNoETH, PairWithFNFTAndWETH} from "./utils/utils.sol";
import {SafeMath} from "../contracts/libraries/math/SafeMath.sol";


// Test FNFT reserve price logic with PriceOracle to verify whether if it returns the correct price based
// on different conditions.
contract FNFTWithPriceOracleTest is DSTest, ERC721Holder {
    using SafeMath for uint256;

    CheatCodes public vm;

    WETH public weth;
    IPriceOracle public priceOracle;
    IUniswapV2Factory public pairFactory;
    FNFTFactory public factory;
    FNFTSettings public settings;
    MockNFT public token;
    FNFT public fNFT;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    PairWithFNFTAndWETH public pair;

    Curator public curator;

    function setUp() public {
        // Set up fNFT environment.
        (vm, weth, pairFactory, priceOracle, settings, factory, fNFT) = SetupEnvironment.setup(100 ether, 1000 ether);

        // Initialize mock fNFT-WETH pair with empty reserves. 
        pair = new PairWithFNFTAndWETH(address(pairFactory), address(fNFT), address(weth), vm);

        // create a curator account
        curator = new Curator(address(factory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fNFT));
        user2 = new User(address(fNFT));
        user3 = new User(address(fNFT));
        user4 = new UserNoETH(address(fNFT));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityBelowThreshold_returnInitialReserve() public {
        /**
        SETUP
         */
        // Transfer fNFT to user to reduce the voting tokens and move below quorum. 
        // Transfer is required since voting quroum is set at 100% during mint. 
        uint256 tokenAmount = fNFT.totalSupply() - ((settings.minVotePercentage() + 100) * fNFT.totalSupply() / 1000);
        fNFT.transfer(address(user1), tokenAmount);
        
        // Transfer remaining of minted fNFT to other user to seting the voting tokens to 0.
        fNFT.transfer(address(user2), fNFT.balanceOf(address(this)));

        /**
        ACTION
         */
        uint256 auctionPrice = fNFT.getAuctionPrice();
        
        /**
        VERIFY
         */
        // verify that the fNFT votes are below quorum.
        assertTrue(fNFT.votingTokens() * 1000 <= settings.minVotePercentage() * fNFT.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= settings.liquidityThreshold());

        // verify that the auction price is equal to initial reserve of fNFT.
        assertEq(auctionPrice, fNFT.initialReserve());
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityBelowThreshold_returnUserReservePrice() public {
        /**
        SETUP
         */ 
        // Transfer fNFT to user so that the user holds more than the minium voting percentage.
        fNFT.transfer(address(user1), (settings.minVotePercentage() + 100) * fNFT.totalSupply() / 1000);

        // Transfer remaining of minted fNFT to other user to seting the voting tokens to 0.
        fNFT.transfer(address(user2), fNFT.balanceOf(address(this)));
    
        // Mock the next call as user and update reserve(user) price.
        uint userPrice = _deriveOptimumReservePrice(fNFT.userReservePrice(address(user1)), settings.minReserveFactor(), settings.maxReserveFactor());
        vm.prank(address(user1));
        fNFT.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fNFT.getAuctionPrice();
        
        /**
        VERIFY
         */
        // verify that the fNFT votes are above quorum.
        assertTrue(fNFT.votingTokens() * 1000 > settings.minVotePercentage() * fNFT.totalSupply());

        // verify that the WETH reserves * 2 is lower than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 <= settings.liquidityThreshold());

        // verify that the auction price is equal to user price of fNFT.
        assertEq(auctionPrice, userPrice);
    }

    function testGetAuctionPrice_whenVotingBelowQuorumAndLiquidityAboveThreshold_compareTWAPAndInitialReserve() public {
        /**
        SETUP
         */
        // Transfer half of fNFT total supply and total weth supply to Pair to create liquidity.
        pair.receiveToken(fNFT.totalSupply() / 2, weth.totalSupply());

        // Update TWAP for fNFT in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Transfer fNFT to user so that the user holds less than the minimum voting percentage.
        fNFT.transfer(address(user1), settings.minVotePercentage() * fNFT.totalSupply() / 1000 - 1 ether);

        // Transfer the remaining fNFT to other user to reduce the initial quorum set to 100%.
        fNFT.transfer(address(user2), fNFT.balanceOf(address(this)));

        // Mock the next call as user and update user reserve price.
        uint userPrice = _deriveOptimumReservePrice(fNFT.userReservePrice(address(user1)), 
                                                    settings.minReserveFactor(), 
                                                    settings.maxReserveFactor());
        vm.prank(address(user1));
        fNFT.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fNFT.getAuctionPrice();

        /**
        VERIFY
         */
        // Verify that the quorum has not been reached.
        assertTrue(fNFT.votingTokens() * 1000 < settings.minVotePercentage() * fNFT.totalSupply());

        // Verify that the WETH reserves * 2 is higher than the liquidity threshold.
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > settings.liquidityThreshold());

        // Verify that the auction price returns the compared price between TWAP and initial reserve.
        uint256 twapPrice = priceOracle.getfNFTPriceETH(address(fNFT), fNFT.totalSupply());
        uint256 initialReservePrice = fNFT.initialReserve();
        assertEq(auctionPrice, twapPrice > initialReservePrice ? twapPrice : initialReservePrice);
    }

    function testGetAuctionPrice_whenVotingAboveQuorumAndLiquidityAboveThreshold_compareTWAPAndUserReservePrice() public {
        /**
        SETUP
         */
        // Distribute fNFT amongst users(fNFT holders) and liquidity pair.
        uint256 pairFNFTAmount = fNFT.totalSupply() / 2;
        uint256 userFNFTAmount = fNFT.totalSupply() / 2;
        pair.receiveToken(pairFNFTAmount, settings.liquidityThreshold() + 1 ether);
        fNFT.transfer(address(user1), userFNFTAmount);
        
        // // Update TWAP for fNFT in WETH minimum required number of times to retrieve TWAP from price oracle.
        _updatePriceOracleMinimumTimes(address(priceOracle), address(pair.uPair()));

        // Update user reserve price that is greater than twap price.
        uint256 userPrice = _deriveOptimumReservePrice(fNFT.userReservePrice(address(user1)), settings.minReserveFactor(), settings.maxReserveFactor());
        vm.prank(address(user1)); 
        fNFT.updateUserPrice(userPrice);

        /**
        ACTION
         */
        uint256 auctionPrice = fNFT.getAuctionPrice();

        /**
        VERIFY
        */
        // verify that voting is above quorum and liquidity is above threshold.
        assertTrue(fNFT.votingTokens() * 1000 > settings.minVotePercentage() * fNFT.totalSupply());
        (, uint256 wethReserve) = pair.getReserves();
        assertTrue(wethReserve * 2 > settings.liquidityThreshold());

        // verify that the auction price selects the maximum price between twap and user reserve price.
        uint256 reservePrice = fNFT.reservePrice();
        uint256 twapPrice = priceOracle.getfNFTPriceETH(address(fNFT), fNFT.totalSupply());
        assertEq(auctionPrice, reservePrice >= twapPrice ? reservePrice : twapPrice);
    }

    function testBuyItNow() public {
        /**
        SETUP
         */
        // Setup environment where weth supply is more than the buy now price. 
        uint256 fNFTAmount = 10 ether;
        uint256 wethAmount = fNFT.buyItNowPrice();
        (vm, weth, pairFactory, priceOracle, settings, factory, fNFT) = SetupEnvironment.setup(fNFTAmount, wethAmount);
        // Transfer ETH to user to pay for NFT.
        weth.transfer(address(user1), weth.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and call to purchase the NFT.
        vm.startPrank(address(user1));
        fNFT.buyItNow{value: fNFT.buyItNowPrice()}();
        vm.stopPrank();

        /**
        VERIFY
         */
        // verify that the user holds 1 NFT token after the purchase.
        assertEq(IERC721(fNFT.token()).balanceOf(address(user1)), 1);
        // verify that the fNFT contract holds the buy it now price.
        assertEq(weth.balanceOf(address(fNFT)), fNFT.buyItNowPrice());
    }

    function testCannotUpdateUserPrice_whenNoVotingTokensAndPriceTooHigh() public {
        /**
        SETUP
         */
        // Transfer all of fNFT to user to give all of voting power.
        fNFT.transfer(address(user1), fNFT.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set higher than the maxium reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fNFT.initialReserve() * settings.maxReserveFactor() + 1 ether) / 1000;
        vm.expectRevert(bytes("update:reserve price too high"));
        vm.startPrank(address(user1));
        fNFT.updateUserPrice(userPrice);
    }

    function testCannotUpdateUserPrice_whenNoVotingTokensAndPriceTooLow() public {
        /**
        SETUP
         */
        // Transfer all of fNFT to user to give all of voting power.
        fNFT.transfer(address(user1), fNFT.totalSupply());

        /**
        ACTION
         */
        // Mock the next call as the user and update the user price which is set lower than the minimum reserve price relative to intial reserve price,
        // since the total voting token is set to 0.
        uint256 userPrice = (fNFT.initialReserve() * settings.minReserveFactor() - 1 ether) / 1000;
        vm.expectRevert(bytes("update:reserve price too low"));
        vm.startPrank(address(user1));
        fNFT.updateUserPrice(userPrice);
    }

    /**
    Derive optimum reserve price by calulating the average between minReserveFactor 
    and maxReserveFactory and add to current fNFT reserve price. 
     */
    function _deriveOptimumReservePrice(uint256 _currentUserPrice, uint256 _minReserveFactor, uint256 _maxReserveFactor) internal pure returns (uint256) {
        uint256 averageReserveFactor = (_minReserveFactor + _maxReserveFactor) / 2;
        _currentUserPrice = _currentUserPrice == 0 ? 1 ether : _currentUserPrice;
        return _currentUserPrice + (_currentUserPrice * averageReserveFactor / 1000);
    }

    /**
    Update pair info in PriceOracle minimum number of times that is required to get fNFT price in ETH.
     */
    function _updatePriceOracleMinimumTimes(address _priceOracle, address _pair) internal {
        PairInfo memory pairInfo = IPriceOracle(_priceOracle).getPairInfo(_pair);
        uint blockTimestampLast = pairInfo.blockTimestampLast;
    
        // Move block.timestamp forward and sync uniswap pair and update price oracle.
        // Update price oracle pair 10 times to meet the requirement.
        uint jump = priceOracle.period();
        for (uint i = 0; i <= priceOracle.minimumPairInfoUpdate(); i++) {
            blockTimestampLast += jump;
            vm.warp(blockTimestampLast);
            IUniswapV2Pair(_pair).sync();
            priceOracle.updatePairInfo(pairInfo.token0, pairInfo.token1);
        }
    }

    receive() external payable {}
}
