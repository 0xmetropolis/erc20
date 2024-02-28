// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {TOKEN_FACTORY_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {TokenFactory} from "../src/TokenFactory.sol";

contract DeployFactory is Script {
    function run() public returns (TokenFactory) {
        vm.broadcast();
        TokenFactory tokenFactory = new TokenFactory();

        console.log("tokenFactory", address(tokenFactory));

        return tokenFactory;
    }
}
