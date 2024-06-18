// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TOKEN_FACTORYV2_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {AirdropFactory} from "../src/AirdropFactory.sol";

contract DeployAirdropFactory is Script {
    function run() public returns (AirdropFactory) {
        return _run(vm.envAddress("OWNER"));
    }

    function _run(address _owner) public returns (AirdropFactory) {
        vm.broadcast();
        AirdropFactory tokenFactory = new AirdropFactory{salt: TOKEN_FACTORYV2_SALT}(_owner);

        console.log("tokenFactory", address(tokenFactory));

        return tokenFactory;
    }
}
