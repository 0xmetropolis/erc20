// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MetalFunFactoryV2, INonfungiblePositionManager} from "../src/MetalFunFactoryV2.sol";
import {calculatePrices, TickMath} from "../src/lib/priceCalc.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";

contract testMetalFunFactoryV2 is Test {
    address recipient = address(0x0123);
    address owner = address(0x4567);

    MetalFunFactoryV2 metalFunFactoryV2;

    function setUp() public {
        metalFunFactoryV2 = new MetalFunFactoryV2(owner);
    }

    function testCalculatePrices(uint256 wantPrice, uint256 totalSupply, uint256 recipientAmount)
        public
    {
        wantPrice = bound(wantPrice, 100, 0.98 ether);
        totalSupply = bound(totalSupply, 1 ether, 100_000_000_000 ether);
        recipientAmount = bound(recipientAmount, 0, totalSupply / 100);

        for (uint256 j = 0; j < 5; j++) {
            (InstantLiquidityToken token,) = metalFunFactoryV2.deploy(
                "TestToken", "TT", wantPrice, totalSupply, recipient, recipientAmount
            );

            // Check recipient balance is the same as the recipientAmount after deployment
            uint256 balance = token.balanceOf(recipient);
            assertEq(
                balance, recipientAmount, "Recipient did not receive the correct amount of tokens"
            );
        }
    }

    /**
     *  COUNTER EXAMPLES
     */

    /// @dev edge case found where the sqrtPrice equaled an initial tick which was perfectly divisible by 200
    ///     therefore, the starting price was "within" the liquidity range
    function testCalculatePrices_CE_1() public {
        for (uint256 j = 0; j < 5; j++) {
            metalFunFactoryV2.deploy(
                "TestToken", "TT", 486769778188445599, 1000000000000000001, recipient, 5844
            );
        }
    }
}
