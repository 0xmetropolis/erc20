// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactoryV2, InstantLiquidityToken} from "../src/TokenFactoryV2.sol";

contract DeployTokenV2 is Script {
    function run() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0x01);
        recipients[1] = address(0x02);

        vm.broadcast();
        _runWithAirdrop(0x62245F030B2A623B14f514B9a0213Ad1e0d92C29, recipients);
    }

    function _runWithAirdrop(address _factory, address[] memory _recipients)
        public
        returns (InstantLiquidityToken, uint256)
    {
        TokenFactoryV2 factory = TokenFactoryV2(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop("", "", _recipients);

        console.log("token", address(token));

        return (token, lpTokenId);
    }

    function _runWithAirdropNoOwner(address _factory, address[] memory _recipients)
        public
        returns (InstantLiquidityToken, uint256)
    {
        TokenFactoryV2 factory = TokenFactoryV2(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop_noOwnerDistribution("", "", _recipients);

        console.log("token", address(token));

        return (token, lpTokenId);
    }
}
