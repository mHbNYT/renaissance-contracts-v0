//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {IFNFTSettings, FNFTSettings} from "../contracts/FNFTSettings.sol";
import {IIFOSettings, IFOSettings} from "../contracts/IFOSettings.sol";
import {IPriceOracle} from "../contracts/interfaces/IPriceOracle.sol";
import {FNFTFactory, ERC721Holder} from "../contracts/FNFTFactory.sol";
import {IFOFactory} from "../contracts/IFOFactory.sol";
import {FNFT} from "../contracts/FNFT.sol";
import {IFO} from "../contracts/IFO.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console, CheatCodes, SetupEnvironment, User, Curator, UserNoETH} from "./utils/utils.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    FNFTFactory public fnftFactory;
    IFOFactory public ifoFactory;
    FNFTSettings public fNFTSettings;
    IFOSettings public ifoSettings;
    WETH public weth;
    IPriceOracle public priceOracle;
    MockNFT public nft;
    FNFT public fractionalizedNFT;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        (vm, weth, , priceOracle) = SetupEnvironment.setup();

        fNFTSettings = new FNFTSettings(address(weth), address(priceOracle));
        fNFTSettings.setGovernanceFee(10);

        ifoSettings = new IFOSettings();

        fnftFactory = new FNFTFactory(address(fNFTSettings));
        ifoFactory = new IFOFactory(address(ifoSettings));

        nft = new MockNFT();

        nft.mint(address(this), 1);

        nft.setApprovalForAll(address(fnftFactory), true);
        fractionalizedNFT = FNFT(
            fnftFactory.mint(
                "testName",
                "TEST",
                address(nft),
                1, // tokenId
                1000e18, //supply: minted to the fractionalizer
                20 ether, // listPrice: the initial reserve price
                50 // the % * 10 fee minted to the fractionalizer anually
            )
        );

        // create a curator account
        curator = new Curator(address(fnftFactory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(fractionalizedNFT));
        user2 = new User(address(fractionalizedNFT));
        user3 = new User(address(fractionalizedNFT));
        user4 = new UserNoETH(address(fractionalizedNFT));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    /// -------------------------------
    /// -------- INIT FUNCTIONS -------
    /// -------------------------------

    function testPause() public {
        ifoFactory.pause();
        ifoFactory.unpause();
    }

    function testCreateIFO() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fractionalizedNFT.balanceOf(address(fNFTIfo)), fractionalizedNFT.totalSupply());
        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());        
    }

    function testFail_createIFOInvalidAddress() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(0), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFONotEnoughSupply() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));
        //burn 1
        fractionalizedNFT.transferFrom(address(this), address(0), 1);
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOAmountForSaleTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            0, //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOAmountForSaleTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this))+1, //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }
    
    function testFail_createIFOCapTooHigh() public {

    }

    function testFail_createIFOCapTooLow() public {

    }

    function testFail_createIFODurationTooLow() public {

    }

    function testFail_createIFODurationTooHigh() public {

    }

    function testCannotCreateWhenPaused() public {
        ifoFactory.pause();
        uint256 thisBalance = fractionalizedNFT.balanceOf(address(this));
        vm.expectRevert(bytes("Pausable: paused"));
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            thisBalance, //amountForSale
            0.02 ether, //price per token
            1e18, // max amount someone can buy
            30 days, //sale duration
            false // allow whitelist
        );
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testUpdateFNFTAddress() public {

    }

    function testFail_updateFNFTAddressNotGov() public {

    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testAddWhitelist() public {

    }

    function testFail_addWhitelistNotCurator() public {

    }

    function testFail_addWhitelistWhitelistNotAllowed() public {

    }

    function testAddMultipleWhitelist() public {

    }

    function testFail_addMultipleWhitelistNotCurator() public {

    }

    function testFail_addMultipleWhitelistWhitelistNotAllowed() public {

    }

    function testRemoveWhitelist() public {

    }

    function testFail_removeWhitelistNotCurator() public {

    }

    function testStart() public {

    }    

    function testFail_startNotCurator() public {

    }

    function testTogglePause() public {

    }

    function testFail_togglePauseNotCurator() public {

    }

    function testEnd() public {

    }

    function testFail_endWhilePaused() public {

    }

    function testFail_endNotCurator() public {

    }

    function testWithdrawProfit() public {

    }

    function testFail_withdrawProfitNotCurator() public {

    }

    function testApproveUtilityContract() public {

    }

    function testFail_notUtilityContract() public {

    }

    function testFail_approveNotCurator() public {

    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testDeposit() public {

    }

    function testFail_depositAfterSaleEnded() public {
        
    }

    function testFail_depositBeforeSaleStarted() public {

    }

    function testFail_depositIfNotWhitelisted() public {

    }

    function testFail_depositOverLimit() public {

    }

    function testGetUserRemainingAllocation() public {

    }    
}
