// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {METAL_FUN_FACTORY_V2_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalFunFactoryV2} from "../src/MetalFunFactoryV2.sol";

contract DeployMetalFunFactory is Script {
    function run() public returns (MetalFunFactoryV2) {
        return _run(vm.envAddress("OWNER"));
    }

    function _run(address _owner) public returns (MetalFunFactoryV2) {
        vm.broadcast();
        MetalFunFactoryV2 metalFunFactoryV2 =
            new MetalFunFactoryV2{salt: METAL_FUN_FACTORY_V2_SALT}(_owner);

        console.log("MetalFunFactory", address(metalFunFactoryV2));

        return metalFunFactoryV2;
    }
}
