// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IFNFTCollection.sol";
import "./interfaces/ILPStaking.sol";
import "./interfaces/IStakingZap.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IVaultManager.sol";
import "./interfaces/IWETH.sol";

contract StakingZap is IStakingZap, Ownable, ReentrancyGuard, ERC721HolderUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IUniswapV2Router public immutable override router;
  IVaultManager public immutable override vaultManager;
  IWETH public immutable override WETH;

  ILPStaking public override lpStaking;

  uint256 public override lpLockTime = 48 hours;

  constructor(address _vaultManager, address _router) Ownable() ReentrancyGuard() {
    router = IUniswapV2Router(_router);
    vaultManager = IVaultManager(_vaultManager);
    WETH = IWETH(IUniswapV2Router(_router).WETH());
    IERC20Upgradeable(address(IUniswapV2Router(_router).WETH())).safeApprove(_router, type(uint256).max);
  }

  receive() external payable {
    if (msg.sender != address(WETH)) revert OnlyWETH();
  }

  function rescue(address token) external override onlyOwner {
    if (token == address(0)) {
      (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
      if (!success) revert CallFailed();
    } else {
      IERC20Upgradeable(token).safeTransfer(msg.sender, IERC20Upgradeable(token).balanceOf(address(this)));
    }
  }

  function setLPLockTime(uint256 _lpLockTime) external override onlyOwner {
    if (_lpLockTime > 7 days) revert LockTooLong();
    emit LPLockTimeUpdated(lpLockTime, _lpLockTime);
    lpLockTime = _lpLockTime;
  }

	function stakeLiquidityETH(
		uint256 vaultId,
    address vault,
    uint256 minTokenIn,
    uint256 minWethIn,
    uint256 wethIn,
    address to
	) external payable override nonReentrant returns (uint256, uint256, uint256) {
		if (to == address(0) || to == address(this)) revert InvalidDestination();
		WETH.deposit{value: msg.value}();

		return _addLiquidityAndLock(vaultId, vault, minTokenIn, minWethIn, wethIn, to);
	}

	function stakeLiquidityWETH(
		uint256 vaultId,
    address vault,
    uint256 minTokenIn,
    uint256 minWethIn,
    uint256 wethIn,
    address to
	) external override nonReentrant returns (uint256, uint256, uint256) {
		if (to == address(0) || to == address(this)) revert InvalidDestination();
		IERC20Upgradeable(address(WETH)).safeTransferFrom(msg.sender, address(this), wethIn);

		return _addLiquidityAndLock(vaultId, vault, minTokenIn, minWethIn, wethIn, to);
	}

  function unlockAndRemoveLiquidityETH(
    uint256 vaultId,
    address vault,
    uint256 amount,
    uint256 minTokenOut,
    uint256 minEthOut,
    address to
  ) external override returns (uint256, uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    if (!vaultManager.excludedFromFees(address(this))) revert NotExcluded();

    lpStaking.claimRewardsTo(vaultId, to);
    lpStaking.withdraw(vaultId, amount);

    (uint256 amountToken, uint256 amountEth) = router.removeLiquidityETH(
      address(vault),
      amount,
      minTokenOut,
      minEthOut,
      to,
      block.timestamp
    );

    return (amountToken, amountEth);
  }

  function unlockAndRemoveLiquidityWETH(
    uint256 vaultId,
    address vault,
    uint256 amount,
    uint256 minTokenOut,
    uint256 minEthOut,
    address to
  ) external override returns (uint256, uint256) {
    if (to == address(0) || to == address(this)) revert InvalidDestination();
    if (!vaultManager.excludedFromFees(address(this))) revert NotExcluded();

    lpStaking.claimRewardsTo(vaultId, to);
    lpStaking.withdraw(vaultId, amount);

    (uint256 amountToken, uint256 amountWeth) = router.removeLiquidity(
      address(vault),
      address(WETH),
      amount,
      minTokenOut,
      minEthOut,
      to,
      block.timestamp
    );

    return (amountToken, amountWeth);
  }

	function _addLiquidityAndLock(
		uint256 vaultId,
    address vault,
    uint256 minTokenIn,
    uint256 minWethIn,
    uint256 wethIn,
    address to
	) internal returns (uint256, uint256, uint256) {
		if (!vaultManager.excludedFromFees(address(this))) revert NotExcluded();

		// Provide liquidity.
    IERC20Upgradeable(vault).safeApprove(address(router), minTokenIn);

		(uint256 amountToken, uint256 amountEth, uint256 liquidity) = router.addLiquidity(
      address(vault),
      address(WETH),
      minTokenIn,
      wethIn,
      minTokenIn,
      minWethIn,
      address(this),
      block.timestamp
    );

		// Stake in LP rewards contract
    address lpToken = _pairFor(vault, address(WETH));
    IERC20Upgradeable(lpToken).safeApprove(address(lpStaking), liquidity);
    lpStaking.timelockDepositFor(vaultId, to, liquidity, lpLockTime);

		uint256 remaining = minTokenIn-amountToken;
    if (remaining != 0) {
      IERC20Upgradeable(vault).safeTransfer(to, remaining);
    }

		uint256 lockEndTime = block.timestamp + lpLockTime;
    emit UserStaked(vaultId, minTokenIn, liquidity, lockEndTime, to);
    return (amountToken, amountEth, liquidity);
	}

  // calculates the CREATE2 address for a pair without making any external calls
  function _pairFor(address tokenA, address tokenB) internal view returns (address pair) {
    (address token0, address token1) = _sortTokens(tokenA, tokenB);
    pair = address(uint160(uint256(keccak256(abi.encodePacked(
      hex'ff',
      router.factory(),
      keccak256(abi.encodePacked(token0, token1)),
      hex'754e1d90e536e4c1df81b7f030f47b4ca80c87120e145c294f098c83a6cb5ace' // init code hash
    )))));
  }
}