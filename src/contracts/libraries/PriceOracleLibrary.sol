//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "../interfaces/IUniswapV2Pair.sol";
import "./UQ112x112.sol";

library PriceOracleLibrary {
    using UQ112x112 for uint224;

    uint8 public constant RESOLUTION = 112;

    // helper function that returns the current block timestamp within the range of uint32, i.e. [0, 2**32 - 1]
    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2 ** 32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(
        address pair
    ) internal view returns (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative += uint(UQ112x112.encode(reserve1).uqdiv(reserve0)) * timeElapsed;
            // counterfactual
            price1Cumulative += uint(UQ112x112.encode(reserve0).uqdiv(reserve1)) * timeElapsed;
        }
    }
}