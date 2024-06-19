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

    uint256 internal constant AIRDROP_ALLOCATION = 253_000;
    address internal owner = address(0xB0b);
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

    function deployAndRun(AirdropFactory _factory,
        string calldata _name,
        string calldata _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        uint256 _minterSupply,
        uint256 _airdropSupply,
        address _minterAddress,
        address[] calldata _airdropAddresses) internal {
        // @spec can deploy a token
        (InstantLiquidityToken token, uint256 lpTokenId) =
            deployAirdropToken._runWithAirdrop(address(_factory), _recipients);

        // @spec calculate expected amount for each recipient plus owner
        uint256 expectedAmount = _recipientAmount / (_recipients.length + 1); // Plus owner

        // @spec assert airdropERC20 for each of the recipients, check balances before airdrop and after.
        for (uint256 i; i < _recipients.length; i++) {
            assertEq(
                token.balanceOf(_recipients[i]), expectedAmount, "expected amount does not match"
            );
        }

        // @spec assert owner balance
        assertEq(
            token.balanceOf(address(deployAirdropToken)),
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

    function test_endToEnd(uint8 addressCount) public {
        // TODO Hard code
        string calldata name = "test";
        string calldata symbol = "TEST";
        uint256 initialPricePerEth = 0.01 ether;
        uint256 totalSupply = 1_000_000_000;
        uint256 minterSupply = 5_000;
        uint256 airdropSupply = 253_000;
        address minterAddress = address(0x123);
        address[] calldata airdropAddresses = new address[](2);
        airdropAddresses[0] = address(0xc0ffee);
        airdropAddresses[1] = address(0xabc);
        airdropAddresses[2] = address(0x987);

        AirdropFactory factory = deployAirdropFactory._run(owner);
        //address[] memory fuzzRecipients = new address[](addressCount);

        // for (uint8 i = 0; i < addressCount; i++) {
        //     airdropAddresses[i] = address(uint160(i + 1));
        // }

        // @spec owner should be correctly initialized
        assertEq(factory.owner(), address(owner));

        deployAndRun(factory,
        string calldata name,
        string calldata symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        uint256 _minterSupply,
        uint256 _airdropSupply,
        address _minterAddress,
        address[] calldata _airdropAddresses) internal {
        // for (uint256 i; i < 25; i++) {
        //     deployAndRun(factory, airdropAddresses, AIRDROP_ALLOCATION);
        // }
    }

    // function test_fuzz_DeployWithAirdrop_noOwnerAllocation(uint8 addressCount) public {
    //     tokenFactory = deployAirdropFactory._run(owner);
    //     address[] memory fuzzRecipients = new address[](addressCount);

    //     // @spec populate the recipients array with generated addresses.
    //     for (uint8 i = 0; i < addressCount; i++) {
    //         fuzzRecipients[i] = address(uint160(i + 1));
    //     }

    //     if (addressCount == 0) vm.expectRevert("must specify recipient addresses");

    //     // @spec deploy token and perform airdrop.
    //     // @spec should call run with airdrop successfully.
    //     // @spec should distribute the correct amount of tokens to each recipient and owner.
    //     (InstantLiquidityToken token,) =
    //         deployAirdropToken._runWithAirdropNoOwner(address(tokenFactory), fuzzRecipients);
    //     console.log('token', address(token));

    //     console.log('addressCount', addressCount);
    //     if (addressCount == 0) return;

    //     // @spec calculate expected amount for each recipient plus owner
    //     uint256 expectedAmount = AIRDROP_ALLOCATION / fuzzRecipients.length;
    //     console.log('fuzzRecipients', fuzzRecipients.length);
    //     console.log('AIRDROP_ALLOCATION', AIRDROP_ALLOCATION);
    //     console.log('expectedAmount', expectedAmount);

    //     // @spec assert airdropERC20 for each of the recipients, check balances after airdrop.
    //     for (uint256 i; i < fuzzRecipients.length; i++) {
    //         assertEq(
    //             token.balanceOf(fuzzRecipients[i]), expectedAmount, "expected amount does not match"
    //         );
    //     }

        // @spec assert owner receives full amount if no other recipients are present.
        // if (fuzzRecipients.length == 0) {
        //     assertEq(
        //         token.balanceOf(address(deployAirdropToken)),
        //         AIRDROP_ALLOCATION,
        //         "Owner's expected amount does not match"
        //     );
        // }
   // }
}
