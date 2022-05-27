// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {NFTXLPStaking} from "../contracts/NFTXLPStaking.sol";
import {NFTXVaultFactoryUpgradeable} from "../contracts/NFTXVaultFactoryUpgradeable.sol";
import {NFTXVaultUpgradeable} from "../contracts/NFTXVaultUpgradeable.sol";
import {NFTXSimpleFeeDistributor} from "../contracts/NFTXSimpleFeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";

/// @author 0xkowloon
/// @title Tests for NFTX vaults
contract NFTXVaultTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  NFTXLPStaking private nftxLPStaking;
  NFTXSimpleFeeDistributor private nftxSimpleFeeDistributor;
  NFTXVaultFactoryUpgradeable private nftxVaultFactory;

  MockNFT public token;

  function setUp() public {
    setupEnvironment(10 ether);
    (
      stakingTokenProvider,
      nftxLPStaking,
      nftxSimpleFeeDistributor,
      nftxVaultFactory
    ) = setupNFTXContracts();

    token = new MockNFT();
  }

  function testVarsAfterFactoryInit() public {
    assertEq(nftxVaultFactory.feeDistributor(), address(nftxSimpleFeeDistributor));
    assertEq(NFTXVaultUpgradeable(nftxVaultFactory.childImplementation()).vaultId(), 0);

    assertEq(nftxVaultFactory.factoryMintFee(), 0.1 ether);
    assertEq(nftxVaultFactory.factoryRandomRedeemFee(), 0.05 ether);
    assertEq(nftxVaultFactory.factoryTargetRedeemFee(), 0.1 ether);
    assertEq(nftxVaultFactory.factoryRandomSwapFee(), 0.05 ether);
    assertEq(nftxVaultFactory.factoryTargetSwapFee(), 0.1 ether);
  }

  function createVault() private {
    nftxVaultFactory.createVault(
      "Doodles",
      "DOODLE",
      address(token),
      false,
      true
    );
  }

  function testCreateVault() public {
    createVault();

    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));
    assertEq(vault.name(), "Doodles");
    assertEq(vault.symbol(), "DOODLE");
    assertEq(vault.assetAddress(), address(token));
    assertEq(vault.manager(), address(this));
    assertEq(vault.owner(), address(this));
    assertTrue(!vault.is1155());
    assertTrue(vault.allowAllItems());

    assertEq(nftxVaultFactory.numVaults(), 1);
    assertEq(nftxVaultFactory.allVaults().length, 1);
    assertEq(nftxVaultFactory.vaultsForAsset(address(token))[0], address(vault));
  }

  function testCreateVaultFactoryIsPaused() public {
    assertTrue(!nftxVaultFactory.isLocked(0));
    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(0);
    assertTrue(nftxVaultFactory.isLocked(0));

    vm.prank(address(1));
    vm.expectRevert("Paused");
    createVault();
  }

  function testCreateVaultOwnerCanBypassPausedFactory() public {
    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(0);
    createVault();

    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));
    assertEq(vault.name(), "Doodles");
  }

  function testSetVaultFees() public {
    nftxVaultFactory.setVaultFees(
      0,
      0.2 ether,
      0.1 ether,
      0.2 ether,
      0.1 ether,
      0.2 ether
    );

    (
      uint256 mintFee,
      uint256 randomRedeemFee,
      uint256 targetRedeemFee,
      uint256 randomSwapFee,
      uint256 targetSwapFee
    ) = nftxVaultFactory.vaultFees(0);

    assertEq(mintFee, 0.2 ether);
    assertEq(randomRedeemFee, 0.1 ether);
    assertEq(targetRedeemFee, 0.2 ether);
    assertEq(randomSwapFee, 0.1 ether);
    assertEq(targetSwapFee, 0.2 ether);
  }

  function testVaultFeesFallback() public {
    createVault();

    (
      uint256 mintFee,
      uint256 randomRedeemFee,
      uint256 targetRedeemFee,
      uint256 randomSwapFee,
      uint256 targetSwapFee
    ) = nftxVaultFactory.vaultFees(0);

    assertEq(mintFee, 0.1 ether);
    assertEq(randomRedeemFee, 0.05 ether);
    assertEq(targetRedeemFee, 0.1 ether);
    assertEq(randomSwapFee, 0.05 ether);
    assertEq(targetSwapFee, 0.1 ether);
  }

  function testSetVaultFeesTooHigh() public {
    createVault();
    vm.expectRevert("Cannot > 0.5 ether");
    nftxVaultFactory.setVaultFees(
      0,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether
    );
  }

  // TODO:
  // "not from vault" error
  // disable vault fees
}