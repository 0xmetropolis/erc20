// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {METAL_FUN_FACTORY_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalFunFactory} from "../src/MetalFunFactory.sol";

contract DeployMetalFunFactory is Script {
    function run() public returns (MetalFunFactory) {
        return _run(vm.envAddress("OWNER"));
    }

    function _run(address _owner) public returns (MetalFunFactory) {
        vm.broadcast();
        MetalFunFactory metalFunFactory = new MetalFunFactory{salt: METAL_FUN_FACTORY_SALT}(_owner);

        console.log("MetalFunFactory", address(metalFunFactory));

        return metalFunFactory;
    }
}
