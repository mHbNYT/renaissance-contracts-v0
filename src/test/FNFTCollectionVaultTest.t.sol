// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "ds-test/test.sol";
import {MockNFT} from "../contracts/mocks/NFT.sol";
import {console, SetupEnvironment} from "./utils/utils.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";
import {LPStaking} from "../contracts/LPStaking.sol";
import {FNFTCollectionVaultFactory} from "../contracts/FNFTCollectionVaultFactory.sol";
import {FNFTCollectionVault} from "../contracts/FNFTCollectionVault.sol";
import {FeeDistributor} from "../contracts/FeeDistributor.sol";
import {StakingTokenProvider} from "../contracts/StakingTokenProvider.sol";

/// @author 0xkowloon
/// @title Tests for FNFT collection vaults
contract FNFTCollectionVaultTest is DSTest, SetupEnvironment {
  StakingTokenProvider private stakingTokenProvider;
  LPStaking private lpStaking;
  FeeDistributor private feeDistributor;
  FNFTCollectionVaultFactory private vaultFactory;
  FNFTCollectionVault private vault;

  MockNFT public token;

  function setUp() public {
    setupEnvironment(10 ether);
    (
      stakingTokenProvider,
      lpStaking,
      feeDistributor,
      vaultFactory
    ) = setupCollectionVaultContracts();

    token = new MockNFT();
  }

  function testVarsAfterFactoryInit() public {
    assertEq(vaultFactory.feeDistributor(), address(feeDistributor));
    assertEq(FNFTCollectionVault(vaultFactory.childImplementation()).vaultId(), 0);

    assertEq(vaultFactory.factoryMintFee(), 0.1 ether);
    assertEq(vaultFactory.factoryRandomRedeemFee(), 0.05 ether);
    assertEq(vaultFactory.factoryTargetRedeemFee(), 0.1 ether);
    assertEq(vaultFactory.factoryRandomSwapFee(), 0.05 ether);
    assertEq(vaultFactory.factoryTargetSwapFee(), 0.1 ether);
  }

  function testCreateVault() public {
    createVault();

    assertEq(vault.name(), "Doodles");
    assertEq(vault.symbol(), "DOODLE");
    assertEq(vault.assetAddress(), address(token));
    assertEq(vault.manager(), address(this));
    assertEq(vault.owner(), address(this));
    assertEq(vault.vaultId(), 0);
    assertEq(address(vault.vaultFactory()), address(vaultFactory));
    assertTrue(!vault.is1155());
    assertTrue(vault.allowAllItems());
    assertTrue(vault.enableMint());
    assertTrue(vault.enableRandomRedeem());
    assertTrue(vault.enableTargetRedeem());
    assertTrue(vault.enableRandomSwap());
    assertTrue(vault.enableTargetSwap());

    assertEq(vaultFactory.numVaults(), 1);
    assertEq(vaultFactory.allVaults().length, 1);
    assertEq(vaultFactory.vaultsForAsset(address(token))[0], address(vault));
  }

  function testCreateVaultFactoryIsPaused() public {
    assertTrue(!vaultFactory.isLocked(0));
    pauseFeature(0);
    assertTrue(vaultFactory.isLocked(0));

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vaultFactory.createVault("Doodles", "DOODLE", address(token), false, true);
  }

  function testCreateVaultOwnerCanBypassPausedFactory() public {
    pauseFeature(0);
    createVault();

    assertEq(vault.name(), "Doodles");
  }

  function testSetVaultFees() public {
    vaultFactory.setVaultFees(
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
    ) = vaultFactory.vaultFees(0);

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
    ) = vaultFactory.vaultFees(0);

    assertEq(mintFee, 0.1 ether);
    assertEq(randomRedeemFee, 0.05 ether);
    assertEq(targetRedeemFee, 0.1 ether);
    assertEq(randomSwapFee, 0.05 ether);
    assertEq(targetSwapFee, 0.1 ether);
  }

  function testSetVaultFeesTooHigh() public {
    createVault();
    vm.expectRevert("Cannot > 0.5 ether");
    vaultFactory.setVaultFees(
      0,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether,
      0.6 ether
    );
  }

  function testSetVaultFeatures() public {
    createVault();

    vault.setVaultFeatures(false, false, false, false, false);

    assertTrue(!vault.enableMint());
    assertTrue(!vault.enableRandomRedeem());
    assertTrue(!vault.enableTargetRedeem());
    assertTrue(!vault.enableRandomSwap());
    assertTrue(!vault.enableTargetSwap());
  }

  function testVaultMint() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);

    // given 2 NFTs, mint 2 vault tokens
    // 10% fee goes to the fee distributor
    // There are no stakers to distribute to, all fees go to treasury
    assertEq(vault.balanceOf(address(this)), 1.8 ether);
    assertEq(vault.balanceOf(0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b), 0.2 ether);

    assertEq(token.balanceOf(address(vault)), 2);
  }

  function testVaultMintPaused() public {
    createVault();

    token.mint(address(1), 1);
    token.mint(address(1), 2);

    vm.prank(address(1));
    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    pauseFeature(1);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.mint(tokenIds, amounts);
  }

  function testVaultMintOwnerCanBypassPausedFactory() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    pauseFeature(1);

    vault.mint(tokenIds, amounts);

    assertEq(vault.balanceOf(address(this)), 1.8 ether);
    assertEq(vault.balanceOf(0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b), 0.2 ether);

    assertEq(token.balanceOf(address(vault)), 2);
  }

  function testVaultMintDisabled() public {
    createVault();

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    vault.setVaultFeatures(false, true, true, true, true);

    vm.expectRevert("Minting not enabled");
    vault.mint(tokenIds, amounts);
  }

  function testTargetRedeem() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vm.prank(address(1));
    vault.redeem(2, redeemTokenIds);

    assertEq(token.balanceOf(address(1)), 2);
    assertEq(token.ownerOf(1), address(1));
    assertEq(token.ownerOf(2), address(vault));
    assertEq(token.ownerOf(3), address(1));
    // 2 ETH + 0.1 ETH per target redeem
    assertEq(vault.balanceOf(address(1)), 0);
  }

  function testTargetRedeemInsufficientBalance() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.19 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vm.prank(address(1));
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.redeem(2, redeemTokenIds);
  }

  function testTargetRedeemDisabled() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vault.setVaultFeatures(true, true, false, true, true);

    vm.prank(address(1));
    vm.expectRevert("FNFTCollectionVault: Target redeem not enabled");
    vault.redeem(2, redeemTokenIds);
  }

  function testTargetRedeemPaused() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    pauseFeature(2);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.redeem(2, redeemTokenIds);
  }

  function testRandomRedeem() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vm.prank(address(1));
    vault.redeem(2, new uint256[](0));

    assertEq(token.balanceOf(address(1)), 2);
    assertEq(token.balanceOf(address(vault)), 1);
    assertEq(vault.balanceOf(address(1)), 0);
  }

  function testRandomRedeemInsufficientBalance() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.09 ether);

    vm.prank(address(1));
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vault.redeem(2, new uint256[](0));
  }

  function testRandomRedeemDisabled() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vault.setVaultFeatures(true, false, true, true, true);

    vm.prank(address(1));
    vm.expectRevert("FNFTCollectionVault: Random redeem not enabled");
    vault.redeem(2, new uint256[](0));
  }

  function testRandomRedeemPaused() public {
    mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    pauseFeature(2);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.redeem(2, new uint256[](0));
  }

  function testTargetSwap() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();

    assertEq(vault.balanceOf(address(1)), 0);
    assertEq(token.ownerOf(2), address(1));
    assertEq(token.ownerOf(3), address(vault));
  }

  function testTargetSwapInsufficientBalance() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.09 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    failedSwap(tokenIds, specificIds, "ERC20: transfer amount exceeds balance");
  }

  function testTargetSwapDisabled() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vault.setVaultFeatures(true, true, true, true, false);

    failedSwap(tokenIds, specificIds, "FNFTCollectionVault: Target swap disabled");
  }

  function testTargetSwapPaused() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    pauseFeature(3);

    failedSwap(tokenIds, specificIds, "Paused");
  }

  function testRandomSwap() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vault.swap(tokenIds, new uint256[](0), new uint256[](0));
    vm.stopPrank();

    assertEq(vault.balanceOf(address(1)), 0);
    assertEq(token.balanceOf(address(1)), 1);
    assertEq(token.ownerOf(3), address(vault));
  }

  function testRandomSwapInsufficientBalance() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.04 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    failedSwap(tokenIds, new uint256[](0), "ERC20: transfer amount exceeds balance");
  }

  function testRandomSwapDisabled() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vault.setVaultFeatures(true, true, true, false, true);

    failedSwap(tokenIds, new uint256[](0), "FNFTCollectionVault: Random swap disabled");
  }

  function testRandomSwapPaused() public {
    mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    pauseFeature(3);

    failedSwap(tokenIds, new uint256[](0), "Paused");
  }

  // TODO:
  // "not from vault" error
  // disable vault fees

  function createVault() private {
    vaultFactory.createVault("Doodles", "DOODLE", address(token), false, true);
    vault = FNFTCollectionVault(vaultFactory.vault(0));
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
    vaultFactory.setIsGuardian(address(this), true);
    vaultFactory.pause(lockId);
  }

  function failedSwap(uint256[] memory tokenIds, uint256[] memory specificIds, string memory errorMessage) private {
    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert(bytes(errorMessage));
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();
  }
}