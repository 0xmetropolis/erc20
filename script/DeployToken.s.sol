// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {SampleToken} from "../src/SampleLiquidityToken.sol";

contract DeployToken is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        SampleToken token = new SampleToken("MyToken", "MYTKN");

        token.initLiquidity();

        vm.stopBroadcast();
    }
}
