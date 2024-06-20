// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AirdropFactory, InstantLiquidityToken} from "../src/AirdropFactory.sol";

contract DeployAirdropToken is Script {
    struct RunParams {
        address factory;
        string name;
        string symbol;
        uint256 initialPricePerEth;
        uint256 totalSupply;
        uint256 minterSupply;
        uint256 airdropSupply;
        address minterAddress;
        address[] airdropAddresses;
    }

    function run() public {
        address[] memory airdropAddresses = new address[](2);
        airdropAddresses[0] = address(0xc0ffee);
        airdropAddresses[1] = address(0x123);

        vm.broadcast();
        RunParams memory params = RunParams({
            factory: 0x13a0dFb64FFaE6BB58bbAB81cA8d17cb259C183f,
            name: "",
            symbol: "",
            initialPricePerEth: 0.01 ether,
            totalSupply: 1_000_000_000,
            minterSupply: 5_000,
            airdropSupply: 253_000,
            minterAddress: airdropAddresses[0],
            airdropAddresses: airdropAddresses
        });
        _run(params);
    }

    function _run(RunParams memory params)
        public returns (InstantLiquidityToken, uint256) {
        AirdropFactory factory = AirdropFactory(params.factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop(params.name, params.symbol, params.initialPricePerEth, params.totalSupply, params.minterSupply, params.airdropSupply, params.minterAddress, params.airdropAddresses);

        console.log("token", address(token));

        return (token, lpTokenId);
    }

}
