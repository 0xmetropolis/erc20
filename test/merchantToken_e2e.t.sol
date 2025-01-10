// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MerchantToken} from "../src/MerchantToken.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {INonfungiblePositionManager} from "../src/TokenFactory.sol";
import {getAddresses} from "../src/lib/addresses.sol";
import {MerchantFactory} from "../src/MerchantFactory.sol";

contract MerchantTokenTest is Test {
    // Events
    event MerchantTransfer(address indexed token, address indexed recipient, uint256 amount);
    event TokenDeployment(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol,
        bool hasLiquidity,
        bool hasDistributionDrop
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DistributionComplete(address indexed token, address[] recipients, uint256 amount);

    // Test addresses
    address owner = makeAddr("owner");
    address maintenance = makeAddr("maintenance");
    address merchant = makeAddr("merchant");
    address[] airdropRecipients = [
        makeAddr("airdropRecipient1"),
        makeAddr("airdropRecipient2"),
        makeAddr("airdropRecipient3")
    ];

    // Token parameters
    uint256 totalSupply = 1_000_000 ether;
    uint256 initialPricePerEth = 0.01 ether;
    uint256 merchantAmount = 100_000 ether;
    uint256 lpAmount = 0; //100_000 ether;
    uint256 airdropAmount = 0; //300_000 ether;

    // Contracts
    MerchantToken merchantToken;
    InstantLiquidityToken testToken;

    function setUp() public {
        merchantToken = new MerchantToken(owner, maintenance);

        // Deploy a test token with initial supply to MerchantToken contract
        vm.startPrank(owner);
        testToken = merchantToken.deployToken(
            "TestToken",
            "TEST",
            0.01 ether,
            1_000_000 ether,
            address(merchantToken), // Mint to contract
            100_000 ether, // Amount for contract
            0, // No LP
            0, // No airdrop
            new address[](0) // Empty recipients
        );
        vm.stopPrank();
    }

    function test_deployToken() public {
        string memory name = "MerchantToken";
        string memory symbol = "MTK";

        vm.startPrank(owner);

        InstantLiquidityToken token = merchantToken.deployToken(
            name,
            symbol,
            initialPricePerEth,
            totalSupply,
            merchant,
            merchantAmount,
            lpAmount,
            airdropAmount,
            airdropRecipients
        );

        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(merchant), merchantAmount);

        vm.stopPrank();
    }

    function test_merchantTransfer() public {
        vm.startPrank(owner);

        uint256 transferAmount = 1000e18;
        uint256 contractBalanceBefore = testToken.balanceOf(address(merchantToken));

        console.log("--- Merchant Transfer Test ---");

        // Start recording logs
        vm.recordLogs();

        // Do the transfer
        merchantToken.merchantTransfer(address(testToken), merchant, transferAmount);

        // Get final balances
        uint256 merchantBalance = testToken.balanceOf(merchant);
        uint256 contractBalanceAfter = testToken.balanceOf(address(merchantToken));

        console.log("Contract Balance After:", contractBalanceAfter);
        console.log("Merchant Balance After:", merchantBalance);
        console.log("Balance Change:", contractBalanceBefore - contractBalanceAfter);

        // Check balances
        assertEq(testToken.balanceOf(merchant), transferAmount, "Merchant balance incorrect");
        assertEq(
            testToken.balanceOf(address(merchantToken)),
            contractBalanceBefore - transferAmount,
            "Contract balance incorrect"
        );

        vm.stopPrank();
    }

    function test_createLiquidityPool() public {
        // Local test token amount for liquidity pool
        uint256 liquidityAmount = 100_000 ether;

        vm.startPrank(owner);

        // Get initial balance
        uint256 initialBalance = testToken.balanceOf(address(merchantToken));

        console.log("--- Liquidity Pool Creation Test ---");
        console.log("Contract's Initial Token Balance:", initialBalance);
        console.log("Requested Pool Liquidity Amount:", liquidityAmount);

        // Create liquidity pool
        uint256 lpTokenId = merchantToken.createLiquidityPool(
            address(testToken), liquidityAmount, initialPricePerEth
        );

        // Get final balance
        uint256 finalBalance = testToken.balanceOf(address(merchantToken));
        uint256 actualChange = initialBalance - finalBalance;

        console.log("Contract's Remaining Token Balance:", finalBalance);
        console.log("Amount Actually Transferred to Pool:", actualChange);
        console.log("LP Token ID:", lpTokenId);

        // Allow for a small rounding difference (up to 10 wei)
        assertApproxEqAbs(
            actualChange, liquidityAmount, 10, "Incorrect amount transferred to liquidity pool"
        );

        vm.stopPrank();
    }
}
