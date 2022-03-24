//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import {Settings} from "../contracts/Settings.sol";
import {ERC721VaultFactory, ERC721Holder} from "../contracts/ERC721VaultFactory.sol";
import {TokenVault} from "../contracts/ERC721TokenVault.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {WETH} from "../contracts/mocks/WETH.sol";
import {console} from "./utils/console.sol";
import {CheatCodes} from "./utils/cheatcodes.sol";

contract User is ERC721Holder {
    TokenVault public vault;

    constructor(address _vault) {
        vault = TokenVault(_vault);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        vault.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        vault.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        vault.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        vault.start{value: _amount}();
    }

    function call_cash() public {
        vault.cash();
    }

    function call_remove(address _user) public {
        vault.removeReserve(_user);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}

contract UserNoETH is ERC721Holder {
    bool public canReceive = true;

    TokenVault public vault;

    constructor(address _vault) {
        vault = TokenVault(_vault);
    }

    function call_transfer(address _guy, uint256 _amount) public {
        vault.transfer(_guy, _amount);
    }

    function call_updatePrice(uint256 _price) public {
        vault.updateUserPrice(_price);
    }

    function call_bid(uint256 _amount) public {
        vault.bid{value: _amount}();
    }

    function call_start(uint256 _amount) public {
        vault.start{value: _amount}();
    }

    function call_cash() public {
        vault.cash();
    }

    function setCanReceive(bool _can) public {
        canReceive = _can;
    }

    // to be able to receive funds
    receive() external payable {
        require(canReceive, "cannot receive ETH");
    } // solhint-disable-line no-empty-blocks
}

contract Curator {
    TokenVault public vault;

    constructor(address _vault) {
        vault = TokenVault(_vault);
    }

    function call_updateCurator(address _who) public {
        vault.updateCurator(_who);
    }

    function call_kickCurator(address _who) public {
        vault.kickCurator(_who);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}

/// @author Nibble Market
/// @title Tests for the vaults
contract VaultTest is DSTest, ERC721Holder {
    CheatCodes public vm;

    ERC721VaultFactory public factory;
    Settings public settings;
    MockNFT public token;
    TokenVault public vault;

    User public user1;
    User public user2;
    User public user3;

    UserNoETH public user4;

    Curator public curator;

    function setUp() public {
        vm = CheatCodes(HEVM_ADDRESS);

        settings = new Settings();

        settings.setGovernanceFee(10);

        factory = new ERC721VaultFactory(address(settings));

        token = new MockNFT();

        token.mint(address(this), 1);

        token.setApprovalForAll(address(factory), true);
        factory.mint("testName", "TEST", address(token), 1, 100e18, 1 ether, 50);

        vault = TokenVault(factory.vaults(0));

        vm.etch(vault.weth(), type(WETH).creationCode);

        // create a curator account
        curator = new Curator(address(factory));

        // create 3 users and provide funds through HEVM store
        user1 = new User(address(vault));
        user2 = new User(address(vault));
        user3 = new User(address(vault));
        user4 = new UserNoETH(address(vault));

        payable(address(user1)).transfer(10 ether);
        payable(address(user2)).transfer(10 ether);
        payable(address(user3)).transfer(10 ether);
        payable(address(user4)).transfer(10 ether);
    }

    function testpause() public {
        factory.pause();
        factory.unpause();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(factory), true);
        factory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 50);
    }

    function testFail_pause() public {
        factory.pause();
        MockNFT temp = new MockNFT();

        temp.mint(address(this), 1);

        temp.setApprovalForAll(address(factory), true);
        factory.mint("testName2", "TEST2", address(temp), 1, 100e18, 1 ether, 50);
    }

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    function testkickCurator() public {
        vault.updateCurator(address(curator));
        assertTrue(vault.curator() == address(curator));
        vault.kickCurator(address(this));
        assertTrue(vault.curator() == address(this));
    }

    function testFail_kickCurator() public {
        curator.call_kickCurator(address(curator));
    }

    function testchangeReserve() public {
        // reserve price here should not change
        vault.transfer(address(user1), 50e18);
        assertEq(vault.reservePrice(), 1 ether);
        assertEq(vault.votingTokens(), 50e18);

        assertEq(vault.userPrices(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(vault.reservePrice(), 1.5 ether);

        // lets pretend user1 found an exploit to push up their reserve price
        vault.removeReserve(address(user1));
        assertEq(vault.userPrices(address(user1)), 0);
        assertEq(vault.reservePrice(), 1 ether);
        assertEq(vault.votingTokens(), 50e18);
    }

    function testFail_changeReserve() public {
        // reserve price here should not change
        vault.transfer(address(user1), 50e18);
        assertEq(vault.reservePrice(), 1 ether);
        assertEq(vault.votingTokens(), 50e18);

        assertEq(vault.userPrices(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(vault.reservePrice(), 1.5 ether);

        // user1 is not gov so cannot do anything
        user1.call_remove(address(this));
    }

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    function testupdateCurator() public {
        vault.updateCurator(address(curator));
        assertTrue(vault.curator() == address(curator));
    }

    function testFail_updateCurator() public {
        curator.call_updateCurator(address(curator));
    }

    function testupdateAuctionLength() public {
        vault.updateAuctionLength(2 weeks);
        assertTrue(vault.auctionLength() == 2 weeks);
    }

    function testFail_updateAuctionLength() public {
        vault.updateAuctionLength(0.1 days);
    }

    function testFail_updateAuctionLength2() public {
        vault.updateAuctionLength(100 weeks);
    }

    function testupdateFee() public {
        vault.updateFee(25);
        assertEq(vault.fee(), 25);
    }

    function testFail_updateFee() public {
        vault.updateFee(101);
    }

    function testclaimFees() public {
        // curator fee is 5%
        // gov fee is 1%
        // we should increase total supply by 6%
        vm.warp(block.timestamp + 31536000 seconds);
        vault.claimFees();
        assertTrue(vault.totalSupply() >= 105999999999900000000 && vault.totalSupply() < 106000000000000000000);
    }

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    function testinitialReserve() public {
        assertEq(vault.reservePrice(), 1 ether);
    }

    function testreservePriceTransfer() public {
        // reserve price here should not change
        vault.transfer(address(user1), 50e18);
        assertEq(vault.reservePrice(), 1 ether);
        assertEq(vault.votingTokens(), 50e18);

        assertEq(vault.userPrices(address(user1)), 0);

        // reserve price should update to 1.5 ether
        user1.call_updatePrice(2 ether);
        assertEq(vault.reservePrice(), 1.5 ether);

        // now user 1 sends 2/5 their tokens to user 2
        // reserve price is now 1 * 5 + 2 * 3 / 8 = 1.375
        user1.call_transfer(address(user2), 20e18);
        assertEq(vault.reservePrice(), 1.375 ether);

        // now they are voting the same as user1 was so we go back to 1.5 eth
        user2.call_updatePrice(2 ether);
        assertEq(vault.reservePrice(), 1.5 ether);

        // send all tokens back to first user
        // their reserve price is 1 ether and they hold all tokens
        user1.call_transfer(address(this), 30e18);
        user2.call_transfer(address(this), 20e18);
        assertEq(vault.reservePrice(), 1 ether);
    }

    function testbid() public {
        vault.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        vault.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        vault.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(vault.auctionState() == TokenVault.State.live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        vault.end();

        assertEq(token.balanceOf(address(user1)), 1);

        // auction has ended. Now lets get all token holders their WETH since they are contracts
        // user1 gets 1/4 of 2 ETH or 0.5 ETH
        // user2 gets 1/4 of 2 ETH or 0.5 ETH
        // this gets 1/2 of 2 ETH or 1 ETH
        uint256 user1Bal = address(user1).balance;
        uint256 user2Bal = address(user2).balance;
        uint256 user3Bal = address(user3).balance;

        user1.call_cash();
        uint256 wethBal = address(user1).balance;
        assertEq(user1Bal + 499425318811235702, wethBal);

        user2.call_cash();
        wethBal = address(user2).balance;
        assertEq(user2Bal + 499425318811235702, wethBal);

        user3.call_cash();
        wethBal = address(user3).balance;
        assertEq(user3Bal + 998850637622471404, wethBal);

        assertTrue(vault.auctionState() == TokenVault.State.ended);
    }

    function testredeem() public {
        vault.redeem();

        assertTrue(vault.auctionState() == TokenVault.State.redeemed);

        assertEq(token.balanceOf(address(this)), 1);
    }

    function testCannotGetEth() public {
        vault.transfer(address(user1), 25 * 1e18);
        user1.call_updatePrice(1 ether);
        vault.transfer(address(user2), 25 * 1e18);
        user2.call_updatePrice(1 ether);
        vault.transfer(address(user4), 50 * 1e18);
        user4.call_updatePrice(1 ether);

        user4.call_start(1.05 ether);
        user4.setCanReceive(false);
        assertTrue(vault.auctionState() == TokenVault.State.live);
        vm.expectRevert(bytes(""));
        user2.call_bid(1.5 ether);
    }

    function testFail_notEnoughVoting() public {
        // now only 24% of tokens are voting so we fail
        vault.transfer(address(user1), 76e18);

        user1.call_start(1.05 ether);
    }

    function testlistPriceZero() public {
        token.mint(address(this), 2);

        factory.mint("testName", "TEST", address(token), 2, 100e18, 0, 50);

        vault = TokenVault(factory.vaults(1));

        assertEq(vault.votingTokens(), 0);
    }

    function testFail_listPriceZeroNoAuction() public {
        token.mint(address(this), 2);

        factory.mint("testName", "TEST", address(token), 2, 100e18, 0, 50);

        vault = TokenVault(factory.vaults(1));

        User userTemp = new User(address(vault));

        userTemp.call_start(1.05 ether);
    }

    function testtransfer() public {
        vault.transfer(address(user1), 25e18);
    }

    function testauctionEndCurator0() public {
        vault.updateFee(0);
        vault.updateCurator(address(0));
        settings.setGovernanceFee(0);
        vault.transfer(address(user1), 25e18);
        user1.call_updatePrice(1 ether);
        vault.transfer(address(user2), 25e18);
        user2.call_updatePrice(1 ether);
        vault.transfer(address(user3), 50e18);
        user3.call_updatePrice(1 ether);

        user1.call_start(1.05 ether);

        assertTrue(vault.auctionState() == TokenVault.State.live);

        uint256 bal = address(user1).balance;
        user2.call_bid(1.5 ether);
        assertEq(bal + 1.05 ether, address(user1).balance);

        bal = address(user2).balance;
        user1.call_bid(2 ether);
        assertEq(bal + 1.5 ether, address(user2).balance);

        vm.warp(block.timestamp + 7 days);

        vault.end();

        assertEq(token.balanceOf(address(user1)), 1);

        // auction has ended. Now lets get all token holders their WETH since they are contracts
        // user1 gets 1/4 of 2 ETH or 0.5 ETH
        // user2 gets 1/4 of 2 ETH or 0.5 ETH
        // this gets 1/2 of 2 ETH or 1 ETH
        uint256 user1Bal = address(user1).balance;
        uint256 user2Bal = address(user2).balance;
        uint256 user3Bal = address(user3).balance;

        user1.call_cash();
        uint256 wethBal = address(user1).balance;
        assertEq(user1Bal + 0.5 ether, wethBal);

        user2.call_cash();
        wethBal = address(user2).balance;
        assertEq(user2Bal + 0.5 ether, wethBal);

        user3.call_cash();
        wethBal = address(user3).balance;
        assertEq(user3Bal + 1 ether, wethBal);

        assertTrue(vault.auctionState() == TokenVault.State.ended);
    }

    receive() external payable {}
}
