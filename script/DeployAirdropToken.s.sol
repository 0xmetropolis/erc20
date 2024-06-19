// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AirdropFactory, InstantLiquidityToken} from "../src/AirdropFactory.sol";

contract DeployAirdropToken is Script {
    function run() public {
        address[] memory recipients = new address[](2);
        recipients[0] = address(0xc0ffee);
        recipients[1] = address(0x123);

        vm.broadcast();
        // TODO deploy factory, determine real address and replace 0 address with it.
        _runWithMinter(address(0), recipients[0], recipients);
    }
    function _runWithMinter(address _factory, address _minter, address[] memory _recipients)
        public
        returns (InstantLiquidityToken, uint256)
    {
        AirdropFactory factory = AirdropFactory(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop("", "", 0.01 ether, 1_000_000_000, 5_000, 253_000, _minter, _recipients);

        console.log("token", address(token));

        return (token, lpTokenId);
    }

    function _runWithNoMinter(address _factory, address[] memory _recipients)
        public
        returns (InstantLiquidityToken, uint256)
    {
        AirdropFactory factory = AirdropFactory(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop("", "", 0.01 ether, 1_000_000_000, 0, 253_000, address(0), _recipients);

        console.log("token", address(token));

        return (token, lpTokenId);
    }

}
