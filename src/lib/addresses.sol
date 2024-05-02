// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {INonfungiblePositionManager} from "../TokenFactory.sol";

function getAddresses()
    view
    returns (address weth, INonfungiblePositionManager nonFungiblePositionManager)
{
    uint256 chainId = block.chainid;
    // Mainnet, Goerli, Arbitrum, Optimism, Polygon
    nonFungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    // mainnet
    if (chainId == 1) weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // goerli
    if (chainId == 5) weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    // arbitrum
    if (chainId == 42161) weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    // optimism
    if (chainId == 10) weth = 0x4200000000000000000000000000000000000006;
    // polygon
    if (chainId == 137) weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    // bnb
    if (chainId == 56) {
        weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        nonFungiblePositionManager =
            INonfungiblePositionManager(0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613);
    }
    // base
    if (chainId == 8453) {
        weth = 0x4200000000000000000000000000000000000006;
        nonFungiblePositionManager =
            INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    }
    // base sepolia
    if (chainId == 84532) {
        weth = 0x4200000000000000000000000000000000000006;
        nonFungiblePositionManager =
            INonfungiblePositionManager(0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2);
    }
    // sepolia
    if (chainId == 11155111) {
        weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
        nonFungiblePositionManager =
            INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
    }
    // zora
    if (chainId == 7777777) {
        weth = 0x4200000000000000000000000000000000000006;
        nonFungiblePositionManager =
            INonfungiblePositionManager(0xbC91e8DfA3fF18De43853372A3d7dfe585137D78);
    }
    // degen chain
    if (chainId == 666666666) {
        // wrapped degen
        weth = 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387;
        nonFungiblePositionManager =
        // proxy swap
         INonfungiblePositionManager(0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f);
    }
}
