// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {AirdropFactory, InstantLiquidityToken} from "../src/AirdropFactory.sol";

contract DeployAirdropToken is Script {
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
        AirdropFactory factory = AirdropFactory(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop("test", "TEST", 0.01 ether, 1_000_000_000, 253_000, _recipients);

        return (token, lpTokenId);
    }

    function _runWithAirdropNoOwner(address _factory, address[] memory _recipients)
        public
        returns (InstantLiquidityToken, uint256)
    {
        AirdropFactory factory = AirdropFactory(_factory);

      (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop("test", "TEST", 0.01 ether, 1_000_000_000, 253_000, _recipients);

        return (token, lpTokenId);
    }
}
