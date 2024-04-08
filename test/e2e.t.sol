// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DeployFactory} from "script/DeployFactory.s.sol";
import {DeployToken} from "script/DeployToken.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {
    TokenFactory, INonfungiblePositionManager, OWNER_ALLOCATION
} from "../src/TokenFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
}

contract TestEndToEndDeployment is Test {
    DeployFactory internal deployFactory;
    DeployToken internal deployToken;

    address internal recipient = address(0xA11c3);
    address internal owner = address(0xB0b);
    address internal feeRecipient = address(0xFe3);
    address internal rando = address(0x111111);

    event TokenFactoryDeployment(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol
    );

    function setUp() public {
        deployFactory = new DeployFactory();
        deployToken = new DeployToken();
    }

    function _test(TokenFactory _factory) internal {
        // @spec can deploy a token
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: true, checkData: false});
        emit TokenFactoryDeployment(address(0), 0, recipient, "InstantLiquidityToken", "ILT");
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deployToken._runWithRecipient(address(_factory), recipient);

        // @spec owner should be correctly initialized
        assertEq(_factory.owner(), address(owner));

        // @spec the factory should be the owner of the LP token
        (, INonfungiblePositionManager nonFungiblePositionManager) = getAddresses();
        assertEq(nonFungiblePositionManager.ownerOf(lpTokenId), address(_factory));

        // @spec recipient should receive their allocation
        assertEq(token.balanceOf(recipient), OWNER_ALLOCATION);

        // @spec owner can call collect fees
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = lpTokenId;
        // @spec collect fees should call the nonFungiblePositionManager
        vm.expectCall(
            address(nonFungiblePositionManager),
            abi.encodeWithSelector(
                INonfungiblePositionManager.collect.selector,
                INonfungiblePositionManager.CollectParams({
                    tokenId: lpTokenId,
                    recipient: feeRecipient,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            )
        );
        vm.prank(owner);
        _factory.collectFees(feeRecipient, tokenIds);
        // @spec the factory should still hold the lp token
        assertEq(nonFungiblePositionManager.ownerOf(lpTokenId), address(_factory));

        // @spec non owner can't collect fees
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        _factory.collectFees(feeRecipient, tokenIds);
    }

    function test_endToEnd() public {
        TokenFactory factory = deployFactory._run(owner);

        for (uint256 i; i < 25; i++) {
            _test(factory);
        }
    }
}
