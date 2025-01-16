// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MetalFactory} from "../src/MetalFactory.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Custom errors
error INVALID_AMOUNT();
error UNSUPPORTED_CHAIN();
error PRICE_TOO_HIGH();
error EXCEEDS_LP_RESERVE();
error OwnableUnauthorizedAccount(address account);

contract MetalTokenTest is Test {
    // Events
    event MerchantTransfer(address indexed token, address indexed recipient, uint256 amount);
    event TokenDeployment(
        address indexed token,
        address indexed recipient,
        string name,
        string symbol,
        bool hasLiquidity,
        bool hasDistributionDrop
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Test addresses
    address owner = makeAddr("owner");
    address merchant = makeAddr("merchant");

    // Token parameters
    uint256 totalSupply = 1_000_000 ether;
    uint256 initialPricePerEth = 0.01 ether;
    uint256 merchantAmount = 100_000 ether;
    uint256 lpAmount = 100_000 ether; // LP reserve amount for contract

    // Contracts
    MetalFactory metalFactory;
    InstantLiquidityToken testToken;

    function setUp() public {
        metalFactory = new MetalFactory(owner);

        // Deploy a test token with initial supply to MerchantToken and lpReserve
        vm.startPrank(owner);
        testToken = metalFactory.deployToken(
            "TestToken",
            "TEST",
            1_000_000 ether,
            address(metalFactory), // Mint to merchant
            100_000 ether, // Amount for merchant
            0, // LP reserve amount
            0, // Airdrop reserve
            0 // Rewards reserve
        );
        vm.stopPrank();
    }

    function test_deployToken() public {
        string memory name = "MerchantToken";
        string memory symbol = "MTK";

        console.log("\n--- Token Deployment Test ---");

        vm.startPrank(owner);

        InstantLiquidityToken token = metalFactory.deployToken(
            name,
            symbol,
            totalSupply,
            merchant,
            merchantAmount,
            0, // LP reserve
            0, // Airdrop reserve
            0 // Rewards reserve
        );

        console.log("\nDeployed Token Details:");
        console.log("Token Address:", address(token));
        console.log("Total Supply:", token.totalSupply());

        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(merchant), merchantAmount);
        vm.stopPrank();
    }

    function test_merchantTransfer() public {
        vm.startPrank(owner);

        uint256 transferAmount = 1000e18;
        uint256 contractBalanceBefore = testToken.balanceOf(address(metalFactory));

        console.log("--- Merchant Transfer Test ---");

        // Start recording logs
        vm.recordLogs();

        // Do the transfer
        metalFactory.merchantTransfer(address(testToken), merchant, transferAmount);

        // Get final balances
        uint256 merchantBalance = testToken.balanceOf(merchant);
        uint256 contractBalanceAfter = testToken.balanceOf(address(metalFactory));

        console.log("Contract Balance After:", contractBalanceAfter);
        console.log("Merchant Balance After:", merchantBalance);
        console.log("Balance Change:", contractBalanceBefore - contractBalanceAfter);

        // Check balances
        assertEq(testToken.balanceOf(merchant), transferAmount, "Merchant balance incorrect");
        assertEq(
            testToken.balanceOf(address(metalFactory)),
            contractBalanceBefore - transferAmount,
            "Contract balance incorrect"
        );

        vm.stopPrank();
    }

    function test_createLiquidityPool() public {
        // Local test token amount for liquidity pool
        uint256 liquidityAmount = 100_000 ether;

        vm.startPrank(owner);

        // Deploy new token with LP reserve
        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(metalFactory),
            merchantAmount,
            liquidityAmount, // LP reserve
            0, // Airdrop reserve
            0 // Rewards reserve
        );

        // Get initial balance
        uint256 initialBalance = token.balanceOf(address(metalFactory));

        console.log("--- Liquidity Pool Creation Test ---");
        console.log("Contract's Initial Token Balance:", initialBalance);
        console.log("Requested Pool Liquidity Amount:", liquidityAmount);

        // Create liquidity pool
        uint256 lpTokenId = metalFactory.createLiquidityPool(address(token), initialPricePerEth);

        // Get final balance
        uint256 finalBalance = token.balanceOf(address(metalFactory));
        uint256 actualChange = initialBalance - finalBalance;

        console.log("Contract's Remaining Token Balance:", finalBalance);
        console.log("Amount Actually Transferred to Pool:", actualChange);
        console.log("LP Token ID:", lpTokenId);

        // Allow for a small rounding difference (up to 10 wei)
        assertApproxEqAbs(
            actualChange, liquidityAmount, 10, "Incorrect amount transferred to liquidity pool"
        );
        assertEq(metalFactory.lpReserves(address(token)), 0, "LP reserve not reset to zero");

        vm.stopPrank();
    }

    function test_RevertWhen_PriceTooHigh() public {
        uint256 highPrice = 0.99 ether; // Above 0.98 ether limit
        // Set the price to a high value and expect revert
        vm.startPrank(owner);
        vm.expectRevert(PRICE_TOO_HIGH.selector);
        metalFactory.createLiquidityPool(address(testToken), highPrice);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerCallsCreatePool() public {
        vm.startPrank(merchant); // Not the owner

        // Expect revert when non-owner calls createPool
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, merchant));

        metalFactory.createLiquidityPool(address(testToken), initialPricePerEth);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroLpAmount() public {
        // Zero liquidity pool amount
        vm.startPrank(owner);
        vm.expectRevert(INVALID_AMOUNT.selector);
        metalFactory.createLiquidityPool(address(testToken), initialPricePerEth);
        vm.stopPrank();
    }

    function test_RevertWhen_UnsupportedChain() public {
        // Change chainid to an unsupported value
        vm.chainId(999);

        // Expect revert when deploying on unsupported chain
        vm.expectRevert(UNSUPPORTED_CHAIN.selector);
        metalFactory = new MetalFactory(owner);
    }

    function test_fuzz_createLiquidityPool(uint256 randomLpAmount, uint256 randomPrice) public {
        // Ensure the random values are within reasonable bounds
        uint256 maxLpAmount = totalSupply - merchantAmount; // Ensure we account for merchant amount
        uint256 maxPrice = 0.98 ether;
        uint256 minPrice = 0.0001 ether;

        // Constrain the random inputs using bound()
        uint256 fuzzedLpAmount = bound(randomLpAmount, 1 ether, maxLpAmount);
        uint256 fuzzedPrice = bound(randomPrice, minPrice, maxPrice);

        console.log("Fuzz Test Inputs - LP Amount:", fuzzedLpAmount, "Price:", fuzzedPrice);

        // Deploy a new token with the random LP reserve
        vm.startPrank(owner);
        InstantLiquidityToken token = metalFactory.deployToken(
            "FuzzToken",
            "FZT",
            totalSupply,
            address(metalFactory),
            merchantAmount,
            fuzzedLpAmount, // Random LP reserve
            0, // Airdrop reserve
            0 // Rewards reserve
        );

        // Create liquidity pool with constrained price
        metalFactory.createLiquidityPool(address(token), fuzzedPrice);

        // Verify LP reserve is set to 0 after pool creation
        assertEq(metalFactory.lpReserves(address(token)), 0, "LP reserve not reset to zero");
        vm.stopPrank();
    }
}
