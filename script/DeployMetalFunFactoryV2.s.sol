// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {METAL_FUN_FACTORY_V2_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalFunFactoryV2} from "../src/MetalFunFactoryV2.sol";

contract DeployMetalFunFactory is Script {
    function run() public returns (MetalFunFactoryV2) {
        return _run(0x71e1BB6EA5B84E9Aa55691a1E86223d250a18F8F);
    }

    function _run(address _owner) public returns (MetalFunFactoryV2) {
        vm.broadcast();
        MetalFunFactoryV2 metalFunFactoryV2 =
            new MetalFunFactoryV2{salt: METAL_FUN_FACTORY_V2_SALT}(_owner);

        console.log("MetalFunFactory", address(metalFunFactoryV2));

        return metalFunFactoryV2;
    }
}
