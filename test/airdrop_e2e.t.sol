// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {getAddresses} from "../src/lib/addresses.sol";
import {DeployAirdropFactory} from "../script/DeployAirdropFactory.s.sol";
import {DeployAirdropToken} from "../script/DeployAirdropToken.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {
    AirdropFactory,
    INonfungiblePositionManager
} from "../src/AirdropFactory.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestEndToEndAirdrop is Test {
    DeployAirdropFactory internal deployAirdropFactory;
    DeployAirdropToken internal deployAirdropToken;
    AirdropFactory internal tokenFactory;

    uint256 internal constant TOTAL_SUPPLY = 1_000_000_000;
    uint256 internal constant AIRDROP_SUPPLY = 253_000;
    uint256 internal constant MINTER_SUPPLY = 5_000;
    address internal owner = address(0xB0b);
    address internal minter = address(0x789);
    address internal feeRecipient = address(0xFe3);
    address internal rando = address(0x111111);

    event DeploymentWithAirdrop(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol
    );

    function setUp() public {
        deployAirdropFactory = new DeployAirdropFactory();
        deployAirdropToken = new DeployAirdropToken();
    }

    function deployAndRun(AirdropFactory _factory, address[] memory _airdropAddresses, uint256 _minterSupply) internal {
        // @spec can deploy a token
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deployAirdropToken._run(address(_factory), "", "", 0.01 ether, TOTAL_SUPPLY, _minterSupply, AIRDROP_SUPPLY, minter, _airdropAddresses);

        // @spec calculate expected amount for each recipient
        uint256 expectedAmount = AIRDROP_SUPPLY / (_airdropAddresses.length);

        // @spec assert airdropERC20 for each of the recipients, check balances before airdrop and after.
        for (uint256 i; i < _airdropAddresses.length; i++) {
            assertEq(
                token.balanceOf(_airdropAddresses[i]), expectedAmount, "expected airdrop amount does not match"
            );
        }

        // @spec assert minter balance
        assertEq(
            token.balanceOf(address(minter)),
            _minterSupply,
            "expected minter amount does not match"
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

        uint8 addressCount = 253;
        AirdropFactory factory = deployAirdropFactory._run(owner);
        address[] memory fuzzRecipients = new address[](addressCount);

        for (uint8 i = 0; i < addressCount; i++) {
            fuzzRecipients[i] = address(uint160(i + 1));
        }

        // @spec owner should be correctly initialized
        assertEq(factory.owner(), address(owner));

        // test with a minter
        deployAndRun(factory, fuzzRecipients, MINTER_SUPPLY);
        // test without a minter
        deployAndRun(factory, fuzzRecipients, 0);
    }


}
