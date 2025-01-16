// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MetalFactory, InstantLiquidityToken} from "../src/MetalFactory.sol";

contract DeployMetalToken is Script {
    function run() public {
        _run(0xABBE7cED99e42D6729Ea7F2E72B225e7157866D2);
    }

    function _run(address _factory) public returns (InstantLiquidityToken) {
        vm.broadcast();
        MetalFactory factory = MetalFactory(_factory);
        InstantLiquidityToken token = factory.deployToken("MetalToken", "MT", 1000_000_000, address(123), 0, 0, 0, 0);

        console.log("token", address(token));

        return token;
    }
}