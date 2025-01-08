// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {MerchantToken} from "../src/MerchantToken.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {INonfungiblePositionManager} from "../src/TokenFactory.sol";
import {getAddresses} from "../src/lib/addresses.sol";
import {MerchantFactory} from "../src/MerchantFactory.sol";
import {Vm} from "forge-std/Vm.sol";

contract MerchantTokenTest is Test {
    MerchantToken merchantToken;
    address owner = makeAddr("owner");
    address merchant = makeAddr("recipient");
    address airdropReserve = makeAddr("airdropReserve");
    address rewardsReserve = makeAddr("rewardsReserve");
    address lpReserve = makeAddr("lpReserve");

    function setUp() public {
        merchantToken = new MerchantToken(owner);
    }

    function test_deployToken() public {
        string memory name = "MerchantToken";
        string memory symbol = "MTK";
        uint256 totalSupply = 1_000_000e18;

        vm.startPrank(owner);

        InstantLiquidityToken token = merchantToken.deployToken(
            name,
            symbol,
            totalSupply,
            merchant,
            0, // merchantAmount
            0, // airdropAmount
            0, // rewardsAmount
            0, // lpAmount
            lpReserve,
            rewardsReserve,
            airdropReserve
        );

        console2.log("Token deployed at:", address(token));

        vm.stopPrank();
    }
}
