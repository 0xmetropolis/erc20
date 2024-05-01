// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MetalFunFactory, InstantLiquidityToken} from "../src/MetalFunFactory.sol";

contract DeployMetalFunToken is Script {
    function run() public {
        vm.broadcast();
        _run(0x773fd11aFeFbcBc7EF98fC51030D99C9f5605904);
    }

    function _run(address _factory) public returns (InstantLiquidityToken, uint256) {
        MetalFunFactory factory = MetalFunFactory(_factory);
        (InstantLiquidityToken token, uint256 lpTokenId) = factory.deploy("", "");

        console.log("token", address(token));

        return (token, lpTokenId);
    }
}
