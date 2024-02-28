// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DeployFactory} from "script/DeployFactory.s.sol";
import {DeployToken} from "script/DeployToken.s.sol";

import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {TokenFactory} from "../src/TokenFactory.sol";

contract TestEndToEndDeployment is Test {
    DeployFactory public deployFactory;
    DeployToken public deployToken;

    function setUp() public {
        deployFactory = new DeployFactory();
        deployToken = new DeployToken();
    }
    function test_endToEnd() public {
        TokenFactory factory = deployFactory.run();

        for(uint256 i; i < 50; i++) deployToken._run(address(factory));
    }
}