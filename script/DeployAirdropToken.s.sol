// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AirdropFactory, InstantLiquidityToken} from "../src/AirdropFactory.sol";

contract DeployAirdropToken is Script {
    function run() public {
        address[] memory airdropAddresses = new address[](2);
        airdropAddresses[0] = address(0xc0ffee);
        airdropAddresses[1] = address(0x123);

        vm.broadcast();
        _run(0xCdDCA68c35cf86230EcBcfBA5437e8B97b237A05, "", "", 0.01 ether, 1_000_000_000, 5_000, 253_000, airdropAddresses[0], airdropAddresses);
    }


    function _run(
        address _factory,
        string memory _name,
        string memory _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        uint256 _minterSupply,
        uint256 _airdropSupply,
        address _minterAddress,
        address[] memory _airdropAddresses)
    public returns (InstantLiquidityToken, uint256) {
        AirdropFactory factory = AirdropFactory(_factory);

        (InstantLiquidityToken token, uint256 lpTokenId) =
            factory.deployAndAirdrop(_name, _symbol, _initialPricePerEth, _totalSupply, _minterSupply, _airdropSupply, _minterAddress, _airdropAddresses);

        console.log("token", address(token));

        return (token, lpTokenId);
    }

}
