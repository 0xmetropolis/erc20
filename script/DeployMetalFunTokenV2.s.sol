// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MetalFunFactoryV2, InstantLiquidityToken} from "../src/MetalFunFactoryV2.sol";

contract DeployMetalFunTokenV2 is Script {
    function run() public {
        vm.broadcast();
        _run(0xf0E8778E80D0D012c84F45A501122A77eF3Db099);
    }

    function _run(address _factory) public returns (InstantLiquidityToken, uint256) {
        MetalFunFactoryV2 factory = MetalFunFactoryV2(_factory);
        (InstantLiquidityToken token, uint256 lpTokenId, address tokenAddress) =
            factory.deploy("", "", 0.01 ether, 1000_000_000, address(0), 0);

        console.log("token", address(token));

        return (token, lpTokenId);
    }
}
