// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {getAddresses} from "../src/lib/addresses.sol";
import {DeployToken} from "script/DeployToken.s.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {MetalFunFactory, INonfungiblePositionManager} from "../src/MetalFunFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestMetalFunFactory is Test {
    MetalFunFactory internal metalFunFactory;
    address internal owner = address(0xB0b);
    address internal recipient = address(0xA11c3);
    address internal feeRecipient = address(0x5EeC);
    address internal rando = address(0x5EeC);

    function setUp() public {
        metalFunFactory = new MetalFunFactory(owner);
    }

    function _test() internal {
        // @spec deploy a token
        vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: false, checkData: true});
        emit MetalFunFactory.TokenFactoryDeployment(
            address(0), 0, address(0), "InstantLiquidityToken", "ILT"
        );

        (, uint256 lpTokenId) = metalFunFactory.deploy("InstantLiquidityToken", "ILT");

        // @spec owner should be correctly initialized
        assertEq(metalFunFactory.owner(), address(owner));

        // @spec the factory should be the owner of the LP token
        (, INonfungiblePositionManager nonFungiblePositionManager) = getAddresses();
        assertEq(nonFungiblePositionManager.ownerOf(lpTokenId), address(metalFunFactory));

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
        metalFunFactory.collectFees(feeRecipient, tokenIds);
        // @spec the factory should still hold the lp token
        assertEq(nonFungiblePositionManager.ownerOf(lpTokenId), address(metalFunFactory));

        // @spec non owner can't collect fees
        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        metalFunFactory.collectFees(feeRecipient, tokenIds);
    }

    function test_endToEnd() public {
        for (uint256 i; i < 25; i++) {
            _test();
        }

        vm.prank(owner);
        metalFunFactory.setInstantLiquidityToken(address(0x1234));

        vm.prank(rando);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, rando));
        metalFunFactory.setInstantLiquidityToken(rando);
    }
}
