// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {FlashBorrower} from "./utils/FlashBorrower.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionFactory, IFNFTCollectionFactory} from "../contracts/FNFTCollectionFactory.sol";
import {IPausable} from "../contracts/interfaces/IPausable.sol";
import {VaultManager} from "../contracts/VaultManager.sol";
import {FNFTCollection, IFNFTCollection} from "../contracts/FNFTCollection.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {ERC20FlashMintUpgradeable} from "../contracts/token/ERC20FlashMintUpgradeable.sol";

/// @author 0xkowloon
/// @title Tests for FNFTCollection vault auctions
contract FNFTCollectionAuctionTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  VaultManager private vaultManager;
  FNFTCollectionFactory private fnftCollectionFactory;
  FNFTCollection private vault;
  MockNFT private token;

  address private bidderOne = address(1);
  address private bidderTwo = address(2);

  function setUp() public {
    setupEnvironment(10 ether);
    (   stakingTokenProvider,
        lpStaking,
        ,
        ,
        ,
        feeDistributor,
        vaultManager,
        ,
        fnftCollectionFactory,
    ) = setupContracts();

    token = new MockNFT();
  }

  function testGetAuctionInactive() public {
    mintVaultTokens(1);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.getAuction(1);
  }

  function testStartAuction() public {
    startAuction();

    assertEq(vault.balanceOf(bidderOne), 0);
    (uint256 livePrice, uint256 end, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, 1e18);
    assertEq(end, block.timestamp + 3 days);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderOne);
  }

  function testStartAuctionFor1155Tokens() public {
  }

  function testStartAuctionBidDisabled() public {
    mintVaultTokens(2);

    vault.transfer(bidderOne, 1e18);

    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionPaused() public {
    pauseFeature(1);

    mintVaultTokens(2);

    vault.transfer(bidderOne, 1e18);

    vm.expectRevert(IFNFTCollection.Paused.selector);
    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionAuctionLive() public {
    startAuction();

    vault.transfer(bidderTwo, 1e18);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.AuctionLive.selector);
    vault.startAuction(1, 1e18);
  }

  function testStartAuctionBidTooLow() public {
    mintVaultTokens(2);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.BidTooLow.selector);
    vault.startAuction(1, 9e17);

  }

  function testBid() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);

    assertEq(vault.balanceOf(bidderOne), 1e18);
    assertEq(vault.balanceOf(bidderTwo), 0);

    (uint256 livePrice, uint256 end, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, newBid);
    assertEq(end, block.timestamp + 3 days);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderTwo);
  }

  function testBidBidDisabled() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vault.setVaultFeatures(true, false, false, false, false, false);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.bid(1, newBid);
  }

  function testBidPaused() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    pauseFeature(1);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.Paused.selector);
    vault.bid(1, newBid);
  }

  function testBidAuctionNotLive() public {
    mintVaultTokens(2);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.bid(1, 1e18);
  }

  function testBidBidTooLow() public {
    startAuction();

    uint256 newBid = 10499e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.BidTooLow.selector);
    vault.bid(1, newBid);
  }

  function testBidAuctionEnded() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.warp(block.timestamp + 3 days);

    vm.prank(bidderTwo);
    vm.expectRevert(IFNFTCollection.AuctionEnded.selector);
    vault.bid(1, newBid);
  }

  function testBidExtendAuctionDuration() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    (,uint256 end,,) = vault.getAuction(1);

    vm.warp(end - 15 minutes);
    uint256 newEnd = end + 15 minutes;

    vm.prank(bidderTwo);
    vault.bid(1, newBid);

    (uint256 livePrice, uint256 endAfterBid, IFNFTCollection.AuctionState state, address winning) = vault.getAuction(1);
    assertEq(livePrice, newBid);
    assertEq(endAfterBid, newEnd);
    assertEq(uint256(state), 1);
    assertEq(winning, bidderTwo);
  }

  function testEndAuction() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    address depositor = address(this);
    uint256 currentDepositorBalance = vault.balanceOf(depositor);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);
    vm.warp(block.timestamp + 3 days);
    vault.endAuction(1);

    vm.expectRevert(IFNFTCollection.AuctionNotLive.selector);
    vault.getAuction(1);

    assertEq(vault.balanceOf(depositor), currentDepositorBalance + 500e14);
    assertEq(token.ownerOf(1), bidderTwo);
    vm.expectRevert(IFNFTCollection.NotInVault.selector);
    vault.getDepositor(1);
  }

  function testEndAuctionBidDisabled() public {
    startAuction();

    uint256 newBid = 10500e14;
    vault.transfer(bidderTwo, newBid);

    vm.prank(bidderTwo);
    vault.bid(1, newBid);
    vm.warp(block.timestamp + 3 days);
    vault.setVaultFeatures(true, false, false, false, false, false);
    vm.expectRevert(IFNFTCollection.BidDisabled.selector);
    vault.endAuction(1);
  }

  function testEndAuctionPaused() public {
  }

  function testEndAuctionAuctionNotLive() public {
  }

  function testEndAuctionAuctionNotEnded() public {
  }

  function testRedeemSwapBidEnabled() public {
  }

  function createVault() private {
    fnftCollectionFactory.createVault(address(token), false, true, "Doodles", "DOODLE");
    vault = FNFTCollection(vaultManager.vault(uint256(0)));
  }

  function mintVaultTokens(uint256 numberOfTokens) private {
    createVault();

    uint256[] memory tokenIds = new uint256[](numberOfTokens);

    for (uint i; i < numberOfTokens; i++) {
      token.mint(address(this), i + 1);
      tokenIds[i] = i + 1;
    }

    token.setApprovalForAll(address(vault), true);

    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
  }

  function pauseFeature(uint256 lockId) private {
    fnftCollectionFactory.setIsGuardian(address(this), true);
    fnftCollectionFactory.pause(lockId);
  }

  function startAuction() private {
    mintVaultTokens(3);
    vault.setVaultFeatures(true, false, false, false, false, true);

    vault.transfer(bidderOne, 1e18);

    vm.prank(bidderOne);
    vault.startAuction(1, 1e18);
  }
}