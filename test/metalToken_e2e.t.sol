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
error NOT_TOKEN_CREATOR();

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
    address creator = makeAddr("creator");

    // Token parameters
    uint256 totalSupply = 1_000_000 ether;
    uint256 initialPricePerEth = 0.01 ether;
    uint256 creatorAmount = 100_000 ether;
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
            address(creator), // Mint to merchant
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
            creator,
            creatorAmount,
            0, // LP reserve
            0, // Airdrop reserve
            0 // Rewards reserve
        );

        console.log("\nDeployed Token Details:");
        console.log("Token Address:", address(token));
        console.log("Total Supply:", token.totalSupply());

        assertEq(token.totalSupply(), totalSupply);
        assertEq(token.balanceOf(creator), creatorAmount);
        vm.stopPrank();
    }

    function test_createLiquidityPool() public {
        // Local test token amount for liquidity pool
        uint256 liquidityAmount = 100_000 ether;

        vm.startPrank(owner); // Call LP creation as owner

        // Deploy new token with LP reserve
        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(metalFactory),
            creatorAmount,
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

    function test_RevertWhen_NonCreatorCallsCreatePool() public {
        address anotherAddress = makeAddr("anotherAddress");
        address tokenAddress = makeAddr("tokenAddress");

        vm.startPrank(anotherAddress);

        // Expect revert when a non-creator tries to call the function
        vm.expectRevert(NOT_TOKEN_CREATOR.selector);

        metalFactory.createLiquidityPool(tokenAddress, lpAmount);
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

    function test_deployToken_with_creator() public {
        address coinCreator = makeAddr("coinCreator");
        uint256 creatorAmount2 = 100_000 ether;

        console.log("--- Deploy Token with Creator Test ---");
        console.log("Coin Creator Address:", coinCreator);
        console.log("Owner Address:", owner);

        // Start prank as coinCreator
        vm.startPrank(coinCreator);

        // Deploy the token
        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(coinCreator),
            creatorAmount2,
            0, // LP reserve
            0, // Airdrop reserve
            0 // Rewards reserve
        );

        // Stop the prank
        vm.stopPrank();

        // Check if the token was deployed correctly
        assertEq(token.totalSupply(), totalSupply, "Total supply should match the expected value");
        assertEq(
            token.balanceOf(coinCreator),
            creatorAmount2,
            "Coin creator balance should match expected amount"
        );
        assertEq(token.name(), "LPToken", "Token name should match the expected value");
        assertEq(token.symbol(), "LPT", "Token symbol should match the expected value");
    }

    function test_fuzz_createLiquidityPool(uint256 randomLpAmount, uint256 randomPrice) public {
        // Ensure the random values are within reasonable bounds
        uint256 maxLpAmount = totalSupply - creatorAmount; // Ensure we account for merchant amount
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
            creatorAmount,
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

    function test_deployToken_with_rewards_and_airdrop() public {
        address coinCreator = makeAddr("coinCreator");
        address signer = makeAddr("signer"); // Address for the signer
        uint256 creatorAmount3 = 10_000 ether;
        uint256 airdropAmount = 10_000 ether; // Example airdrop amount
        uint256 rewardsAmount = 5_000 ether; // Example rewards amount

        console.log("--- Deploy Token with Rewards and Airdrop Test ---");
        console.log("Coin Creator Address:", coinCreator);
        console.log("Signer Address:", signer);
        console.log("Owner Address:", owner);

        // Start prank as signer
        vm.startPrank(signer);

        // Deploy the token with airdrop and rewards
        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(coinCreator),
            creatorAmount3,
            0, // LP reserve
            airdropAmount, // Airdrop reserve
            rewardsAmount // Rewards reserve
        );

        // Stop the prank
        vm.stopPrank();

        // Check if the signer holds both amounts together
        uint256 expectedTotalAmount = airdropAmount + rewardsAmount;
        assertEq(
            token.balanceOf(signer),
            expectedTotalAmount,
            "Signer should receive the total amount of airdrop and rewards"
        );

        // Additional checks for total supply and creator balance
        assertEq(token.totalSupply(), totalSupply, "Total supply should match the expected value");
        assertEq(
            token.balanceOf(coinCreator),
            creatorAmount3,
            "Coin creator balance should match expected amount"
        );
    }
}
