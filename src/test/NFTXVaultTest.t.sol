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

  function testCreateVault() public {
    createVault();

    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));
    assertEq(vault.name(), "Doodles");
    assertEq(vault.symbol(), "DOODLE");
    assertEq(vault.assetAddress(), address(token));
    assertEq(vault.manager(), address(this));
    assertEq(vault.owner(), address(this));
    assertEq(vault.vaultId(), 0);
    assertEq(address(vault.vaultFactory()), address(nftxVaultFactory));
    assertTrue(!vault.is1155());
    assertTrue(vault.allowAllItems());
    assertTrue(vault.enableMint());
    assertTrue(vault.enableRandomRedeem());
    assertTrue(vault.enableTargetRedeem());
    assertTrue(vault.enableRandomSwap());
    assertTrue(vault.enableTargetSwap());

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

  function testSetVaultFeatures() public {
    createVault();
    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

    vault.setVaultFeatures(false, false, false, false, false);

    assertTrue(!vault.enableMint());
    assertTrue(!vault.enableRandomRedeem());
    assertTrue(!vault.enableTargetRedeem());
    assertTrue(!vault.enableRandomSwap());
    assertTrue(!vault.enableTargetSwap());
  }

  function testVaultMint() public {
    createVault();
    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

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
    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

    token.mint(address(1), 1);
    token.mint(address(1), 2);

    vm.prank(address(1));
    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(1);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.mint(tokenIds, amounts);
  }

  function testVaultMintOwnerCanBypassPausedFactory() public {
    createVault();
    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

    token.mint(address(this), 1);
    token.mint(address(this), 2);

    token.setApprovalForAll(address(vault), true);

    uint256[] memory tokenIds = new uint256[](2);
    tokenIds[0] = 1;
    tokenIds[1] = 2;

    uint256[] memory amounts = new uint256[](0);

    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(1);

    vault.mint(tokenIds, amounts);

    assertEq(vault.balanceOf(address(this)), 1.8 ether);
    assertEq(vault.balanceOf(0x511fEFE374e9Cb50baF1E3f2E076c94b3eF8B03b), 0.2 ether);

    assertEq(token.balanceOf(address(vault)), 2);
  }

  function testVaultMintDisabled() public {
    createVault();
    NFTXVaultUpgradeable vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

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
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

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

  function testTargetRedeemDisabled() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    vault.setVaultFeatures(true, true, false, true, true);

    vm.prank(address(1));
    vm.expectRevert("NFTXVault: Target redeem not enabled");
    vault.redeem(2, redeemTokenIds);
  }

  function testTargetRedeemPaused() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

    vault.transfer(address(1), 2.2 ether);

    uint256[] memory redeemTokenIds = new uint256[](2);
    redeemTokenIds[0] = 1;
    redeemTokenIds[1] = 3;

    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(2);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.redeem(2, redeemTokenIds);
  }

  function testRandomRedeem() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vm.prank(address(1));
    vault.redeem(2, new uint256[](0));

    assertEq(token.balanceOf(address(1)), 2);
    assertEq(token.balanceOf(address(vault)), 1);
    assertEq(vault.balanceOf(address(1)), 0);
  }

  function testRandomRedeemDisabled() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    vault.setVaultFeatures(true, false, true, true, true);

    vm.prank(address(1));
    vm.expectRevert("NFTXVault: Random redeem not enabled");
    vault.redeem(2, new uint256[](0));
  }

  function testRandomRedeemPaused() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(3);

    vault.transfer(address(1), 2.1 ether);

    nftxVaultFactory.setIsGuardian(address(this), true);
    nftxVaultFactory.pause(2);

    vm.prank(address(1));
    vm.expectRevert("Paused");
    vault.redeem(2, new uint256[](0));
  }

  function testTargetSwap() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(2);

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

  function testTargetSwapDisabled() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(2);

    vault.transfer(address(1), 0.1 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    uint256[] memory specificIds = new uint256[](1);
    specificIds[0] = 2;

    vault.setVaultFeatures(true, true, true, true, false);

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert("NFTXVault: Target swap disabled");
    vault.swap(tokenIds, new uint256[](0), specificIds);
    vm.stopPrank();
  }

  function testRandomSwap() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(2);

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

  function testRandomSwapDisabled() public {
    NFTXVaultUpgradeable vault = mintVaultTokens(2);

    vault.transfer(address(1), 0.05 ether);

    uint256[] memory tokenIds = new uint256[](1);
    tokenIds[0] = 3;
    token.mint(address(1), 3);

    vault.setVaultFeatures(true, true, true, false, true);

    vm.startPrank(address(1));
    token.setApprovalForAll(address(vault), true);
    vm.expectRevert("NFTXVault: Random swap disabled");
    vault.swap(tokenIds, new uint256[](0), new uint256[](0));
    vm.stopPrank();
  }

  // TODO:
  // "not from vault" error
  // disable vault fees

  function createVault() private {
    nftxVaultFactory.createVault(
      "Doodles",
      "DOODLE",
      address(token),
      false,
      true
    );
  }

  function mintVaultTokens(uint256 numberOfTokens) private returns (NFTXVaultUpgradeable vault) {
    createVault();
    vault = NFTXVaultUpgradeable(nftxVaultFactory.vault(0));

    uint256[] memory tokenIds = new uint256[](numberOfTokens);

    for (uint i; i < numberOfTokens; i++) {
      token.mint(address(this), i + 1);
      tokenIds[i] = i + 1;
    }

    token.setApprovalForAll(address(vault), true);

    uint256[] memory amounts = new uint256[](0);

    vault.mint(tokenIds, amounts);
  }

}