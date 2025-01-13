// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {METAL_TOKEN_SALT} from "../src/Constants.sol";
import {MetalToken} from "../src/MetalToken.sol";

contract DeployMetalToken is Script {
    function run() public returns (MetalToken) {
        return _run(msg.sender);
    }

    function _run(address _owner) public returns (MetalToken) {
        vm.broadcast();
        MetalToken metalToken = new MetalToken{salt: METAL_TOKEN_SALT}(_owner);

        console.log("MetalToken", address(metalToken));

        return metalToken;
    }
}
