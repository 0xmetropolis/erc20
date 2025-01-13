// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MetalToken} from "../src/MetalToken.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {INonfungiblePositionManager} from "../src/TokenFactory.sol";
import {getAddresses} from "../src/lib/addresses.sol";
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
        uint256 indexed tokenId,
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
    MetalToken metalToken;
    InstantLiquidityToken testToken;

    function setUp() public {
        metalToken = new MetalToken(owner, lpAmount);

        // Deploy a test token with initial supply to MerchantToken contract
        vm.startPrank(owner);
        testToken = metalToken.deployToken(
            "TestToken",
            "TEST",
            0.01 ether,
            1_000_000 ether,
            address(metalToken), // Mint to merchant
            100_000 ether, // Amount for merchant
            0 // No initial LP, we'll create pool later
        );
        vm.stopPrank();
    }

    function test_deployToken() public {
        string memory name = "MerchantToken";
        string memory symbol = "MTK";

        console.log("\n--- Token Deployment Test ---");

        vm.startPrank(owner);

        InstantLiquidityToken token = metalToken.deployToken(
            name,
            symbol,
            initialPricePerEth,
            totalSupply,
            merchant,
            merchantAmount,
            0 // No LP amount for this test
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
        uint256 contractBalanceBefore = testToken.balanceOf(address(metalToken));

        console.log("--- Merchant Transfer Test ---");

        // Start recording logs
        vm.recordLogs();

        // Do the transfer
        metalToken.merchantTransfer(address(testToken), merchant, transferAmount);

        // Get final balances
        uint256 merchantBalance = testToken.balanceOf(merchant);
        uint256 contractBalanceAfter = testToken.balanceOf(address(metalToken));

        console.log("Contract Balance After:", contractBalanceAfter);
        console.log("Merchant Balance After:", merchantBalance);
        console.log("Balance Change:", contractBalanceBefore - contractBalanceAfter);

        // Check balances
        assertEq(testToken.balanceOf(merchant), transferAmount, "Merchant balance incorrect");
        assertEq(
            testToken.balanceOf(address(metalToken)),
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
        uint256 initialBalance = testToken.balanceOf(address(metalToken));

        console.log("--- Liquidity Pool Creation Test ---");
        console.log("Contract's Initial Token Balance:", initialBalance);
        console.log("Requested Pool Liquidity Amount:", liquidityAmount);

        // Create liquidity pool
        uint256 lpTokenId =
            metalToken.createLiquidityPool(address(testToken), liquidityAmount, initialPricePerEth);

        // Get final balance
        uint256 finalBalance = testToken.balanceOf(address(metalToken));
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

    function test_RevertWhen_LpAmountExceedsReserve() public {
        uint256 tooMuchLiquidity = lpAmount + 1 ether;
        // Expect revert when lpAmount exceeds reserve
        vm.startPrank(owner);
        vm.expectRevert(EXCEEDS_LP_RESERVE.selector);
        metalToken.createLiquidityPool(address(testToken), tooMuchLiquidity, initialPricePerEth);
        vm.stopPrank();
    }

    function test_RevertWhen_PriceTooHigh() public {
        uint256 highPrice = 0.99 ether; // Above 0.98 ether limit
        // Set the price to a high value and expect revert
        vm.startPrank(owner);
        vm.expectRevert(PRICE_TOO_HIGH.selector);
        metalToken.createLiquidityPool(address(testToken), lpAmount, highPrice);
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerCallsCreatePool() public {
        vm.startPrank(merchant); // Not the owner

        // Expect revert when non-owner calls createPool
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, merchant));

        metalToken.createLiquidityPool(address(testToken), lpAmount, initialPricePerEth);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroLpAmount() public {
        // Zero liquidity pool amount
        vm.startPrank(owner);
        vm.expectRevert(INVALID_AMOUNT.selector);
        metalToken.createLiquidityPool(address(testToken), 0, initialPricePerEth);
        vm.stopPrank();
    }

    function test_RevertWhen_UnsupportedChain() public {
        // Change chainid to an unsupported value
        vm.chainId(999);

        // Expect revert when deploying on unsupported chain
        vm.expectRevert(UNSUPPORTED_CHAIN.selector);
        metalToken = new MetalToken(owner, lpAmount);
    }
}
