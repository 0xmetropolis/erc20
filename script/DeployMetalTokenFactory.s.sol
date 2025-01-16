// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {METAL_TOKEN_SALT} from "../src/Constants.sol";
import {MetalFactory} from "../src/MetalFactory.sol";

contract DeployMetalToken is Script {
    function run() public returns (MetalFactory) {
        return _run(msg.sender);
    }

    function _run(address _owner) public returns (MetalFactory) {
        vm.broadcast();
        MetalFactory metalFactory = new MetalFactory{salt: METAL_TOKEN_SALT}(_owner);

        console.log("MetalFactory", address(metalFactory));

        return metalFactory;
    }
}
