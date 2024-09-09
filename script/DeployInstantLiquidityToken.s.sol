// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {LIQUIDITY_TOKEN_SALT} from "../src/Constants.sol";

contract DeployInstantLiquidityToken is Script {
    function run() public returns (InstantLiquidityToken) {
        vm.broadcast();
        InstantLiquidityToken token =
            new InstantLiquidityToken{salt: LIQUIDITY_TOKEN_SALT}();

        console.log("InstantLiquidityToken", address(token));

        return token;
    }
}