// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

import {TOKEN_DEPLOYER_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalTokenDeployer} from "../src/MetalTokenDeployer.sol";

contract DeployDeployer is Script {
    function run() public returns (MetalTokenDeployer) {
        vm.broadcast();
        MetalTokenDeployer tokenDeployer = new MetalTokenDeployer{salt: TOKEN_DEPLOYER_SALT}();

        console.log("tokenDeployer", address(tokenDeployer));

        return tokenDeployer;
    }
}
