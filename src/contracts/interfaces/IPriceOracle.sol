// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "../libraries/UQ112x112.sol";
import "../libraries/math/FixedPoint.sol";

// Struct that contains metadata of two token pair that is stored in the liquidity pool.
// Metadata used to calculated TWAP (Time-weighted average price).
struct PairInfo {
    address token0;
    address token1;
    uint256 price0CumulativeLast;
    uint256 price1CumulativeLast;
    FixedPoint.uq112x112 price0Average;
    FixedPoint.uq112x112 price1Average;
    uint216 totalUpdates;
    uint32 blockTimestampLast;
    bool exists;
}

interface IPriceOracle {
    function getTwap(address _pair) external view returns (PairInfo memory);

    function updatePairInfo(address _pair) external;

    function updatefNFTTWAP(address fNFT) external;

    function consult(
        address _token,
        address _pair,
        uint256 _amountIn
    ) external view returns (uint256 amountOut);

    function getPairAddress(address _token0, address _token1) external view returns (address pairAddress);

    function getfNFTPriceETH(address _fNFT, uint256 _amountIn) external view returns (uint256 amountOut);
}
