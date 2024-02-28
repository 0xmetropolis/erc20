// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory, InstantLiquidityToken} from "../src/TokenFactory.sol";

contract DeployToken is Script {

    function run() public {
        vm.broadcast();
        _run(0x48A470d5D014F52eC22d8415238E3AA0D4F159DA);
    }
    function _run(address _factory) public returns (InstantLiquidityToken) {
        TokenFactory factory = TokenFactory(_factory);
        InstantLiquidityToken token = factory.deploy("Token", "TKN");

        console.log("token", address(token));

        return token;
    }
}

/*
import {Script, console} from "forge-std/Script.sol";
import {MetalTokenDeployer, InstantLiquidityToken} from "../src/MetalTokenDeployer.sol";

contract DeployToken is Script {
    MetalTokenDeployer deployer = MetalTokenDeployer(0xA423F5A2E6194cF1b080a535158094BBbE619E58);

    function run() public returns (InstantLiquidityToken) {
        vm.broadcast();
        _run();
    }

    function _run() public returns (InstantLiquidityToken) {
        InstantLiquidityToken token = deployer.deploy("Token", "TKN");

        console.log("token", address(token));

        return token;
    }
}

*/