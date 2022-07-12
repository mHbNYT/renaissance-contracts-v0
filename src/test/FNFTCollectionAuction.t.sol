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
  }

  function testBidPaused() public {
  }

  function testBidAuctionNotLive() public {
  }

  function testBidBidTooLow() public {
  }

  function testBidAuctionEnded() public {
  }

  function testBidExtendAuctionDuration() public {
  }

  function testEndAuction() public {
  }

  function testEndAuctionBidDisabled() public {
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