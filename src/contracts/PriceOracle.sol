//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "./libraries/PriceOracleLibrary.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/math/FixedPoint.sol";

import "@openzeppelin/contracts/access/Ownable.sol";


contract PriceOracle is Ownable{
    using FixedPoint for *;

    /**
    1. Store cumulative prices for each pair in the pool
    2. Update to calculate twap and update for each pair
     */
    uint public constant PERIOD = 10 minutes;
    
    // Map of pair address to PairInfo struct, which contains cumulative price, last block timestamps, and etc.
    mapping(address => PairInfo) private pairMap;

    // Struct that contains metadata of two token pair that is stored in the liquidity pool. 
    // Metadata used to calculated TWAP (Time-weighted average price).
    struct PairInfo {
        address token0;
        address token1;
        uint price0CumulativeLast;
        uint price1CumulativeLast;
        FixedPoint.uq112x112 price0Average;
        FixedPoint.uq112x112 price1Average; 
        uint32 blockTimestampLast;
        bool exists; 
    }

    function addPairInfo(address factory, address token0, address token1) external onlyOwner {
        // Get predetermined pair address.
        address pairAddress = UniswapV2Library.pairFor(factory, token0, token1);
        PairInfo storage pairInfo = pairMap[pairAddress];
        require(pairInfo.exists == false, "Pair already exists.");

        // Get pair information for the given pair address.
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
        
        // Ensure that there's liquidity in the pair.
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "No reserved");
        
        // Initialize pairInfo for the 
        pairInfo.token0 = pair.token0();
        pairInfo.token1 = pair.token1();
        pairInfo.price0CumulativeLast = pair.price0CumulativeLast(); // fetch the current accumulated price value (token1 / token0)
        pairInfo.price1CumulativeLast = pair.price1CumulativeLast(); // fetch the current accumulated price value (token0 / token1)
        pairInfo.blockTimestampLast = blockTimestampLast;
        pairInfo.exists = true;
    }
    
    function updatePairInfo(address _pair) external {
        // Require pair to exist in the map.
        PairInfo storage pairInfo = pairMap[_pair];
        require(pairInfo.exists == true, "Pair does not exist.");
        
        // Get cumulative prices for each token pairs and block timestampe in the pool.
        (uint price0Cumulative, uint price1Cumulative, uint32 blockTimestamp) = PriceOracleLibrary.currentCumulativePrices(_pair);
        uint32 timeElapsed = blockTimestamp - pairInfo.blockTimestampLast;
        
        // Ensure that at least one full period has passed since the last update.
        require(timeElapsed >= PERIOD, "Period has not elapsed.");

        // Overflow is desired, casting never truncates.
        // Cumulative price is in (uq112x112 price * seconds) uits so we simply wrap it after division by the time elapsed.
        FixedPoint.uq112x112 memory price0Average = FixedPoint.uq112x112(uint224((price0Cumulative - pairInfo.price0CumulativeLast) / timeElapsed));
        FixedPoint.uq112x112 memory price1Average = FixedPoint.uq112x112(uint224((price1Cumulative - pairInfo.price1CumulativeLast) / timeElapsed));
        pairInfo.price0Average = price0Average;
        pairInfo.price1Average = price1Average;
        pairInfo.price0CumulativeLast = price0Cumulative;
        pairInfo.price1CumulativeLast = price1Cumulative;
        pairInfo.blockTimestampLast = blockTimestamp;
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(address _token, address _pair, uint _amountIn) external view returns (uint amountOut) {
        PairInfo memory pairInfo = pairMap[_pair];
        require(pairInfo.exists == true, "Pair does not exist.");

        if (_token == pairInfo.token0) {
            amountOut = pairInfo.price0Average.mul(_amountIn).decode144();
        } else {
            require(_token == pairInfo.token1, "Invalid token.");
            amountOut = pairInfo.price1Average.mul(_amountIn).decode144();
        }
    }
    
}