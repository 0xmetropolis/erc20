// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenDeployer} from "../src/MetalTokenDeployer.sol";
// import {TestToken} from "../src/TestToken.sol";
// import {MockERC20} from "forge-std/mocks/MockERC20.sol";

uint256 constant mintAmount = 10000000000000000000000000000;

contract DeployToken is Script {
    function setUp() public {}

    function run() public {
        // metal deployer on base
        TokenDeployer deployer = TokenDeployer(
            0xb0d17F33B539833dc7695bF7418BcEDf4Ce9f3Cd
        );

        vm.broadcast();
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            address pool,
            address tokenOut
        ) = deployer.deploy("Token", "TKN");

        console.log("tokenId: ", tokenId);
        console.log("liquidity: ", liquidity);
        console.log("amount0: ", amount0);
        console.log("amount1: ", amount1);
        console.log("pool: ", pool);
        console.log("tokenOut: ", tokenOut);
    }
}
