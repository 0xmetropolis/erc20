// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TOKEN_FACTORYV2_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {TokenFactoryV2} from "../src/TokenFactoryV2.sol";

contract DeployFactoryV2 is Script {
    function run() public returns (TokenFactoryV2) {
        return _run(vm.envAddress("OWNER"));
    }

    function _run(address _owner) public returns (TokenFactoryV2) {
        vm.broadcast();
        TokenFactoryV2 tokenFactory = new TokenFactoryV2{salt: TOKEN_FACTORYV2_SALT}(_owner);

        console.log("tokenFactoryV2", address(tokenFactory));

        return tokenFactory;
    }
}
