// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AIRDROP_FACTORY_SALT} from "../src/Constants.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {AirdropFactory} from "../src/AirdropFactory.sol";

contract DeployAirdropFactory is Script {
    function run() public returns (AirdropFactory) {
        return _run(0x71e1BB6EA5B84E9Aa55691a1E86223d250a18F8F);
    }

    function _run(address _owner) public returns (AirdropFactory) {
        vm.broadcast();
        AirdropFactory tokenFactory = new AirdropFactory{salt: AIRDROP_FACTORY_SALT}(_owner);

        console.log("Airdrop Factory: ", address(tokenFactory));

        return tokenFactory;
    }
}
