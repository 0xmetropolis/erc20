// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MetalToken, InstantLiquidityToken} from "../src/MetalToken.sol";

contract DeployMetalToken is Script {
    function run() public {
        _run(0x6228f692f4F060edFD431119B93Ac30a3C2B8CbB);
    }

    function _run(address _factory) public returns (InstantLiquidityToken) {
        vm.broadcast();
        MetalToken factory = MetalToken(_factory);
        InstantLiquidityToken token = factory.deployToken("", "", 1000_000_000, address(123), 0, 0, 0, 0);

        console.log("token", address(token));

        return token;
    }
}