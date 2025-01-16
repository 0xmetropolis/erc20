// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MetalToken, InstantLiquidityToken} from "../src/MetalToken.sol";

contract DeployMetalToken is Script {
    function run() public {
        _run(0x16f51A0495b4677fcEBA15390D364D1ad78a7384);
    }

    function _run(address _factory) public returns (InstantLiquidityToken) {
        vm.broadcast();
        MetalToken factory = MetalToken(_factory);
        InstantLiquidityToken token = factory.deployToken("", "", 1000_000_000, address(123), 0, 0, 0, 0);

        console.log("token", address(token));

        return token;
    }
}