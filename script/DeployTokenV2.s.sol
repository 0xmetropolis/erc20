// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TokenFactoryV2, InstantLiquidityToken} from "../src/TokenFactoryV2.sol";

contract DeployTokenV2 is Script {
    function run() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0xc0ffee);
        recipients[1] = address(0xc0ffee);

        vm.broadcast();
        _runWithAirdropNoOwner(0x95EFe3BC0318869EB211b267433BF26E03ae875D, recipients);
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
