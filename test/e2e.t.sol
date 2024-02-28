// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DeployDeployer} from "script/DeployDeployer.s.sol";
import {DeployToken} from "script/DeployToken.s.sol";

import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalTokenDeployer} from "../src/MetalTokenDeployer.sol";

contract TestEndToEndDeployment is Test {
    DeployDeployer public deployDeployer;
    DeployToken public deployToken;

    function setUp() public {
        deployDeployer = new DeployDeployer();
        deployToken = new DeployToken();
    }
    function test_endToEnd() public {
        address owner = address(0xa11c3);
        vm.label(owner, "ALICE");

        MetalTokenDeployer deployer = deployDeployer.run();
        InstantLiquidityToken token = deployToken.run();
    }
}