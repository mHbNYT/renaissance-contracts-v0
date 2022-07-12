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
  MockNFT public token;

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

  function testStartAuction() public {
  }

  function testStartAuctionBidDisabled() public {
  }

  function testStartAuctionPaused() public {
  }

  function testStartAuctionAuctionLive() public {
  }

  function testStartAuctionBidTooLow() public {
  }

  function testBid() public {
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
}