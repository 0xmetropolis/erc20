// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {DeployFactoryV2} from "script/DeployFactoryV2.s.sol";
import {DeployTokenV2} from "script/DeployTokenV2.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {
    TokenFactoryV2,
    INonfungiblePositionManager,
    OWNER_ALLOCATION
} from "../src/TokenFactoryV2.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {getAddresses} from "./e2e.t.sol";

contract TestEndToEndDeploymentV2 is Test {
    DeployFactoryV2 internal deployFactoryV2;
    DeployTokenV2 internal deployTokenV2;

    address[] internal recipients;
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
        deployFactoryV2 = new DeployFactoryV2();
        deployTokenV2 = new DeployTokenV2();

        recipients.push(address(1));
        recipients.push(address(2));
        recipients.push(address(3));
        recipients.push(address(4));
        recipients.push(address(5));
    }

    function buyToken(TokenFactoryV2 _factory) internal {
        address[] memory _recipients = recipients;
        // @spec can deploy a token
        // vm.expectEmit({checkTopic1: false, checkTopic2: false, checkTopic3: true, checkData: false});
        // emit TokenFactoryDeployment(address(0), 0, recipient, "InstantLiquidityToken", "ILT");
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deployTokenV2._runWithAirdrop(address(_factory), _recipients);

        // @spec assert Owner allocation is correct
        assertEq(OWNER_ALLOCATION, 8000000000000000000000000000, "owner allocation is not correct");

        // @spec calculate expected amount for each recipient plus owner
        uint256 expectedAmount = OWNER_ALLOCATION / (_recipients.length + 1); // Plus owner

        // @spec assert airdropERC20 for each of the recipients, check balances before airdrop and after.
        for (uint256 i; i < _recipients.length; i++) {
            assertEq(
                token.balanceOf(_recipients[i]), expectedAmount, "expected amount does not match"
            );
        }

        // @spec assert owner balance
        assertEq(
            token.balanceOf(address(deployTokenV2)),
            expectedAmount,
            "expected owner amount does not match"
        );

        // @spec the factory should be the owner of the LP token
        (, INonfungiblePositionManager nonFungiblePositionManager) = getAddresses();
        assertEq(nonFungiblePositionManager.ownerOf(lpTokenId), address(_factory));

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
        TokenFactoryV2 factory = deployFactoryV2._run(owner);

        // @spec owner should be correctly initialized
        assertEq(factory.owner(), address(owner));

        // for (uint256 i; i < 25; i++) {
        buyToken(factory);
        // }
    }
}
