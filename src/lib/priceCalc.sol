// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {TickMath} from "./TickMath.sol";

// constants for scaling and precision
uint256 constant oneEth = 10 ** 18;
uint256 constant tokenDecimals = 10 ** 18;
uint256 constant scale = 10 ** 18;
/// @dev Q96 decimals for fixed-point calculations (see Uniswap V3 docs)
uint256 constant q = 2 ** 96;

/// @dev calculate sqrt prices and corresponding ticks for given token pair and `ethPricePerToken` price
/// @return sqrtPrice - the initial square root price for the token pair:
///    - should map 1:1 for the desired ethPricePerToken
///    - will be outside the liquidity range specified by TickLower and TickUpper
/// @return tickLower - the lower tick of the liquidity range
///    - rounded up to the nearest 100 because the fee is specified at 10_000 or 1%
/// @return tickUpper - the upper tick of the liquidity range
///    - rounded down to the nearest 100 because the fee is specified at 10_000 or 1%
function calculatePrices(address tokenA, address tokenB, uint256 ethPricePerToken)
    pure
    returns (uint160 sqrtPrice, int24 tickLower, int24 tickUpper)
{
    if (tokenA < tokenB) {
        // scale up ethPricePerToken by 18 decimals to prevent rounding errors
        uint256 ethPricePerTokenScaled = ethPricePerToken * scale;
        // square root price the liquidity begins at
        sqrtPrice = uint160(FixedPointMathLib.sqrt(ethPricePerTokenScaled) * q / scale);
        // we just + 1 to adjust the tick in the case where the sqrtPrice is perfectly divisible by 200
        tickLower = (TickMath.getTickAtSqrtRatio(sqrtPrice) + 1) / 100 * 100;
        tickLower = tickLower - (tickLower % 200);
    } else {
        // calculate square root of the price for tokenB per eth
        uint256 oneEthScaled = oneEth * scale;
        uint256 quotient = oneEthScaled / ethPricePerToken;
        // square root price the liquidity begins at
        sqrtPrice = uint160(FixedPointMathLib.sqrt(quotient) * q / FixedPointMathLib.sqrt(scale));
        // we just - 1 to adjust the tick in the case where the sqrtPrice is perfectly divisible by 200
        tickUpper = (TickMath.getTickAtSqrtRatio(sqrtPrice) - 1) / 100 * 100;
        tickUpper = tickUpper - (tickUpper % 200);
    }
}
