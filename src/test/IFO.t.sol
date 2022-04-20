//solhint-disable func-name-mixedcase
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
import {InitializedProxy} from "../contracts/InitializedProxy.sol";

/// @author Nibble Market
/// @title Tests for the fnfts
contract IFOTest is DSTest, ERC721Holder {
    CheatCodes internal vm;

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
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply() + 1, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFOCapTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            0, // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFODurationTooLow() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this))+1, //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration() - 1, //sale duration
            false // allow whitelist
        );
    }

    function testFail_createIFODurationTooHigh() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));        
        ifoFactory.create(
            address(fractionalizedNFT), // wrong address
            fractionalizedNFT.balanceOf(address(this))+1, //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.maximumDuration() + 1, //sale duration
            false // allow whitelist
        );
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
        fractionalizedNFT.approve(address(this), fractionalizedNFT.balanceOf(address(this)));
        fractionalizedNFT.transferFrom(address(this), address(1), fractionalizedNFT.balanceOf(address(this)));

        vm.startPrank(address(1));

        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(1)));

        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(1)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );        
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.stopPrank();

        fNFTIfo.updateFNFTAddress(address(2));

        assertEq(address(fNFTIfo.FNFT()), address(2));
    }

    function testFail_updateFNFTAddresZeroAddress() public {
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

        fNFTIfo.updateFNFTAddress(address(0));
    }

    function testFail_updateFNFTAddressNotGov() public {           
        fractionalizedNFT.approve(address(this), fractionalizedNFT.balanceOf(address(this)));
        fractionalizedNFT.transferFrom(address(this), address(1), fractionalizedNFT.balanceOf(address(this)));

        vm.startPrank(address(1));

        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(1)));

        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(1)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            false // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.updateFNFTAddress(address(1));

        vm.stopPrank();        
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testAddWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(1));

        assertEq(fNFTIfo.whitelisted(address(1)) ? 1 : 0, true ? 1 : 0);
    }

    function testFail_addWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        vm.startPrank(address(1));

        fNFTIfo.addWhitelist(address(1));

        vm.stopPrank();
    }

    function testFail_addWhitelistWhitelistNotAllowed() public {
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

        fNFTIfo.addWhitelist(address(1));
    }

    function testAddMultipleWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(1);
        whitelists[1] = address(2);
        whitelists[2] = address(3);

        fNFTIfo.addMultipleWhitelists(whitelists);

        assertEq(fNFTIfo.whitelisted(address(1)) ? 1 : 0, true ? 1 : 0);
        assertEq(fNFTIfo.whitelisted(address(2)) ? 1 : 0, true ? 1 : 0);
        assertEq(fNFTIfo.whitelisted(address(3)) ? 1 : 0, true ? 1 : 0);
    }

    function testFail_addMultipleWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(1);
        whitelists[1] = address(2);
        whitelists[2] = address(3);

        vm.startPrank(address(1));

        fNFTIfo.addMultipleWhitelists(whitelists);

        vm.stopPrank();
    }

    function testFail_addMultipleWhitelistWhitelistNotAllowed() public {
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

        address[] memory whitelists = new address[](3);

        whitelists[0] = address(1);
        whitelists[1] = address(2);
        whitelists[2] = address(3);

        fNFTIfo.addMultipleWhitelists(whitelists);
    }

    function testRemoveWhitelist() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(1));

        assertEq(fNFTIfo.whitelisted(address(1)) ? 1 : 0, true ? 1 : 0);

        fNFTIfo.removeWhitelist(address(1));

        assertEq(fNFTIfo.whitelisted(address(1)) ? 1 : 0, false ? 1 : 0);
    }

    function testFail_removeWhitelistNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        fNFTIfo.addWhitelist(address(1));

        assertEq(fNFTIfo.whitelisted(address(1)) ? 1 : 0, true ? 1 : 0);

        vm.startPrank(address(1));

        fNFTIfo.removeWhitelist(address(1));

        vm.stopPrank();
    }

    function testStart() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);
    }    

    function testFail_startNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        vm.startPrank(address(1));

        fNFTIfo.start();

        vm.stopPrank();
    }

    function testFail_startAlreadyStarted() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        fNFTIfo.start();        
    }

    function testFail_startAlreadyEnded() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();

        assertEq(fNFTIfo.ended() ? 1 : 0, true ? 1 : 0);        

        fNFTIfo.start();
    }

    function testFail_startDoesNotHaveFNFT() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));

        bytes memory _initializationCalldata = abi.encodeWithSelector(
            IFO.initialize.selector,
            address(this),
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );

        IFO fNFTIfo = new IFO(address(new InitializedProxy(address(new IFO(address(ifoSettings))), _initializationCalldata)));

        fNFTIfo.start();
    }

    function testEnd() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();
    }

    function testFail_endNotCurator() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        vm.startPrank(address(1));

        fNFTIfo.end();

        vm.stopPrank();
    }

    function testFail_endWhilePaused() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();
    }

    function testFail_endBeforeStart() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));     

        assertEq(fNFTIfo.started() ? 1 : 0, false ? 1 : 0);   

        fNFTIfo.end();
    }

    function testFail_endBeforDuration() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration()-1);

        fNFTIfo.end();

    }

    function testFail_endAfterEnd() public {
        fractionalizedNFT.approve(address(ifoFactory), fractionalizedNFT.balanceOf(address(this)));                
        ifoFactory.create(
            address(fractionalizedNFT), // the address of the fractionalized token
            fractionalizedNFT.balanceOf(address(this)), //amountForSale
            0.02 ether, //price per token
            fractionalizedNFT.totalSupply(), // max amount someone can buy
            ifoSettings.minimumDuration(), //sale duration
            true // allow whitelist
        );
        IFO fNFTIfo = IFO(ifoFactory.getIFO(address(fractionalizedNFT)));        

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);   

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();

        assertEq(fNFTIfo.ended() ? 1 : 0, true ? 1 : 0);   

        fNFTIfo.end();
    }

    function testTogglePause() public {
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

        fNFTIfo.start();        

        assertEq(fNFTIfo.started() ? 1 : 0, true ? 1 : 0);

        vm.roll(fNFTIfo.startBlock() + 1000);

        assertEq(block.number, fNFTIfo.startBlock() + 1000);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, true ? 1 : 0);

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration());

        vm.roll(fNFTIfo.pauseBlock() + 1000);

        fNFTIfo.togglePause();

        assertEq(fNFTIfo.paused() ? 1 : 0, false ? 1 : 0);

        assertEq(fNFTIfo.duration(), ifoSettings.minimumDuration() + 1000);        
    }

    function testFail_togglePauseWhenNotStarted() public {
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

        fNFTIfo.togglePause();
    }

    function testFail_togglePauseAfterEnded() public {
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

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        fNFTIfo.end();

        fNFTIfo.togglePause();
    }

    function testFail_togglePauseNotCurator() public {
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

        fNFTIfo.start();        

        vm.roll(fNFTIfo.startBlock() + ifoSettings.minimumDuration());

        vm.startPrank(address(1));

        fNFTIfo.togglePause();

        vm.stopPrank();
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
