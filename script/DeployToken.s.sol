// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory, InstantLiquidityToken} from "../src/TokenFactory.sol";

contract DeployToken is Script {

    function run() public {
        vm.broadcast();
        _run(0xa17a469F46181F231EB717c944a052c4bb9bE8E0);
    }
    function _run(address _factory) public returns (InstantLiquidityToken) {
        TokenFactory factory = TokenFactory(_factory);
        InstantLiquidityToken token = factory.deploy("Token", "TKN");

        console.log("token", address(token));

        return token;
    }
}
