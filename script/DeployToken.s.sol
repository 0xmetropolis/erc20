// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactory, InstantLiquidityToken} from "../src/TokenFactory.sol";

contract DeployToken is Script {
    function run() public {
        vm.broadcast();
        _run(0xCB1FF6e2F166C350b291E6Dc8e32ba27639486bC);
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
