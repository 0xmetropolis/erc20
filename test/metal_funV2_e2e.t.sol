// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MetalFunFactoryV2, INonfungiblePositionManager} from "../src/MetalFunFactoryV2.sol";
import {calculatePrices, TickMath} from "../src/lib/priceCalc.sol";
import {console2} from "forge-std/console2.sol";

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
        vm.assume(wantPrice < 1 ether && wantPrice > 100);
        vm.assume(totalSupply > 1 ether && totalSupply < 100_000_000_000 ether);
        vm.assume(recipientAmount < totalSupply / 100);

        for (uint256 j = 0; j < 5; j++) {
            metalFunFactoryV2.deploy(
                "TestToken", "TT", wantPrice, totalSupply, recipient, recipientAmount
            );
        }
        console2.log(unicode"Pass ✅ for price: ", wantPrice);
    }

    /**
     *  COUNTER EXAMPLES
     */

    /// @dev edge case found where the sqrtPrice equaled an initial tick which was perfectly divisible by 200
    ///     therefore, the starting price was "within" the liquidity range
    function testCalculatePrices_CE_1() public {
        for (uint256 j = 0; j < 5; j++) {
            metalFunFactoryV2.deploy(
                "TestToken", "TT", 486769778188445599, 1000000000000000000, recipient, 5844
            );
        }
    }
}
