// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {MetalTokenDeployer} from "../src/MetalTokenDeployer.sol";
// import {TestToken} from "../src/TestToken.sol";
// import {MockERC20} from "forge-std/mocks/MockERC20.sol";

uint256 constant mintAmount = 10000000000000000000000000000;

contract DeployToken is Script {
    function setUp() public {}

    function deployMetalTokenDeployer() public {
        vm.broadcast();
        MetalTokenDeployer deployer = new MetalTokenDeployer{salt: 1}();
        console.log("Deployer address: ", address(deployer));
    }

    function deployToken() public {
        // metal deployer on base
        MetalTokenDeployer deployer = MetalTokenDeployer{salt: 1}(
            0xF63297b3793E045AC50a7a9670DB29dB38424ED8
        );

        vm.broadcast();
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            address pool,
            address tokenOut
        ) = deployer.deploy("MyToken", "MYTKN", 100);

        console.log("tokenId: ", tokenId);
        console.log("liquidity: ", liquidity);
        console.log("amount0: ", amount0);
        console.log("amount1: ", amount1);
        console.log("pool: ", pool);
        console.log("tokenOut: ", tokenOut);
    }
}
