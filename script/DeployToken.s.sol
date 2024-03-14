// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory, InstantLiquidityToken} from "../src/TokenFactory.sol";

contract DeployToken is Script {
    function run() public {
        vm.broadcast();
        _run(0xB323fFb8e3d9c2376bf3515e7c1677147c36b4A4);
    }

    function _run(address _factory) public returns (InstantLiquidityToken, uint256) {
        TokenFactory factory = TokenFactory(_factory);
        (InstantLiquidityToken token, uint256 lpTokenId) = factory.deploy("", "");

        console.log("token", address(token));

        return (token, lpTokenId);
    }

    function _runWithRecipient(address _factory, address _recipient)
        public
        returns (InstantLiquidityToken, uint256)
    {
        TokenFactory factory = TokenFactory(_factory);
        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployWithRecipient(_recipient, "", "");

        console.log("token", address(token));

        return (token, lpTokenId);
    }
}
