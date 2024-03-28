// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactoryV2, InstantLiquidityToken} from "../src/TokenFactoryV2.sol";

contract DeployTokenV2 is Script {
    function run() public {
        vm.broadcast();
        // _run(0x9E7B76DAf55397278Acc0f858876b59aB686f7Ef); // TODO: update this
    }

    function _runWithAirdrop(address _factory, address _recipient)
        public
        returns (InstantLiquidityToken, uint256)
    {
        TokenFactoryV2 factory = TokenFactoryV2(_factory);

        address[] memory addresses = new address[](5);

        addresses[0] = address(1);
        addresses[1] = address(2);
        addresses[2] = address(3);
        addresses[3] = address(4);
        addresses[4] = address(5);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployWithAirdrop("", "", addresses);

        console.log("token", address(token));

        return (token, lpTokenId);
    }
}
