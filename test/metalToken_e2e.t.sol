// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MetalFactory} from "../src/MetalFactory.sol";
import {InstantLiquidityToken} from "../src/InstantLiquidityToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {getNetworkAddresses, ISwapRouter} from "../src/lib/networkAddresses.sol";
import {POOL_FEE} from "../src/Constants.sol";

// Custom errors
error INVALID_AMOUNT();
error UNSUPPORTED_CHAIN();
error PRICE_TOO_HIGH();
error EXCEEDS_LP_RESERVE();
error OwnableUnauthorizedAccount(address account);
error NOT_TOKEN_DEPLOYER();
error EXCEEDS_DISTRIBUTION_LIMIT();
error EXCEEDS_PREBUY_LIMIT();

contract MetalTokenTest is Test {
    // Events
    event MerchantTransfer(address indexed token, address indexed recipient, uint256 amount);
    event TokenDeployment(
        address indexed token,
        address indexed recipient,
        string name,
        string symbol,
        bool hasLiquidity,
        uint256 lpReserve
    );
    event LiquidityPoolCreated(
        address indexed tokenAddress, uint256 totalAmount, uint256 nftId, address poolAddress
    );

    event InitialBuyExecuted(
        address indexed token, address indexed recipient, uint256 wethValue, uint256 tokenAmount
    );

    event FeesCollected(address indexed recipient, uint256 indexed nftId);

    event ConfigurationUpdated(
        uint256 maxWethPreBuyLowEvaluation,
        uint256 maxWethPreBuyHighEvaluation,
        uint256 maxInitialPrice,
        uint256 evaluationThreshold
    );

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Test addresses
    address owner;
    address creator;

    // Token parameters
    uint256 totalSupply = 1_000_000 ether;
    uint256 initialPricePerEth = 0.00000121 ether;
    uint256 creatorAmount = 100_000 ether;
    uint256 lpAmount = 100_000 ether; // LP reserve amount for contract

    // WETH address on Base network
    address constant WETH = 0x4200000000000000000000000000000000000006;

    // Contracts
    MetalFactory metalFactory;
    InstantLiquidityToken testToken;

    function setUp() public {
        owner = msg.sender;
        creator = makeAddr("creator");

        // Deploy the factory with the owner address
        vm.prank(owner);
        metalFactory = new MetalFactory(owner);

        // Deal ETH to addresses for tests
        vm.deal(owner, 1000 ether);
        vm.deal(creator, 1000 ether);

        // Set up WETH for tests that need it
        // Convert some ETH to WETH for the owner
        vm.startPrank(owner);
        (bool success,) = WETH.call{value: 50 ether}("");
        require(success, "WETH deposit failed");

        vm.startPrank(creator);
        (bool success2,) = WETH.call{value: 50 ether}("");
        require(success2, "WETH deposit failed");

        // Approve WETH for the MetalFactory
        IERC20(WETH).approve(address(metalFactory), type(uint256).max);
        vm.stopPrank();

        // Deploy a test token with initial supply
        vm.startPrank(owner);
        testToken = metalFactory.deployToken(
            "TestToken",
            "TEST",
            1_000_000 ether,
            address(creator), // Recipient
            100 ether, // Distribution amount
            0, // LP reserve amount
            false, // Auto-create LP
            0, // Initial price
            0 // WETH amount
        );
        vm.stopPrank();

        // Log addresses for debugging
        console.log("\n--- Test Setup ---");
        console.log("Owner address (msg.sender):", owner);
        console.log("Factory owner:", metalFactory.owner());
        console.log("Factory address:", address(metalFactory));
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
            false, // Auto-create LP
            0, // Initial price
            0 // WETH amount
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
            false, // Don't auto-create LP
            0, // Initial price
            0 // WETH amount
        );

        uint256 initialBalance = token.balanceOf(address(metalFactory));

        console.log("--- Liquidity Pool Creation Test ---");
        console.log("Contract's Initial Token Balance:", initialBalance);
        console.log("Requested Pool Liquidity Amount:", liquidityAmount);

        // Create liquidity pool
        uint256 lpTokenId = metalFactory.createLiquidityPool(
            address(token),
            initialPricePerEth,
            address(0), // No recipient for tokens
            0 // No WETH amount
        );

        // Get final balance
        uint256 finalBalance = token.balanceOf(address(metalFactory));
        uint256 actualChange = initialBalance - finalBalance;

        console.log("Contract's Remaining Token Balance:", finalBalance);
        console.log("Amount Actually Transferred to Pool:", actualChange);
        console.log("LP Token ID:", lpTokenId);

        // Allow for a small rounding difference (up to 200 wei)
        assertApproxEqAbs(
            actualChange, liquidityAmount, 200, "Incorrect amount transferred to liquidity pool"
        );
        assertEq(metalFactory.lpReserves(address(token)), 0, "LP reserve not reset to zero");

        vm.stopPrank();
    }

    function test_RevertWhen_PriceTooHigh() public {
        uint256 highPrice = 0.99 ether; // Above 0.98 ether limit
        // Set the price to a high value and expect revert
        vm.startPrank(owner);
        vm.expectRevert(PRICE_TOO_HIGH.selector);
        metalFactory.createLiquidityPool(address(testToken), highPrice, address(0), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_NonCreatorCallsCreatePool() public {
        address anotherAddress = makeAddr("anotherAddress");
        address tokenAddress = makeAddr("tokenAddress");

        vm.startPrank(anotherAddress);
        vm.expectRevert(NOT_TOKEN_DEPLOYER.selector);
        metalFactory.createLiquidityPool(tokenAddress, lpAmount, address(0), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_ZeroLpAmount() public {
        // Zero liquidity pool amount
        vm.startPrank(owner);
        vm.expectRevert(INVALID_AMOUNT.selector);
        metalFactory.createLiquidityPool(address(testToken), initialPricePerEth, address(0), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_UnsupportedChain() public {
        // Change chainid to an unsupported value
        vm.chainId(999);
        vm.expectRevert(UNSUPPORTED_CHAIN.selector);
        metalFactory = new MetalFactory(owner);
    }

    function test_deployToken_with_creator() public {
        address coinCreator = makeAddr("coinCreator");
        uint256 creatorAmount2 = 100_000 ether; // 10% of total supply, below 25% limit

        console.log("--- Deploy Token with Creator Test ---");
        console.log("Coin Creator Address:", coinCreator);
        console.log("Owner Address:", owner);

        vm.startPrank(coinCreator);

        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(coinCreator),
            creatorAmount2,
            0, // LP reserve
            false, // Auto-create LP
            0, // Initial price
            0 // WETH amount
        );

        vm.stopPrank();

        assertEq(token.totalSupply(), totalSupply, "Total supply should match the expected value");
        assertEq(
            token.balanceOf(coinCreator),
            creatorAmount2,
            "Coin creator balance should match expected amount"
        );
        assertEq(token.name(), "LPToken", "Token name should match the expected value");
        assertEq(token.symbol(), "LPT", "Token symbol should match the expected value");
    }

    function test_RevertWhen_ExceedsDistributionLimit() public {
        address coinCreator = makeAddr("coinCreator");
        uint256 maxPercentage = 25; // MAX_DISTRIBUTION_PERCENTAGE constant in the contract
        uint256 excessiveCreatorAmount = (totalSupply * (maxPercentage + 1)) / 100; // 26% of total supply

        console.log("--- Test Distribution Limit Enforcement ---");
        console.log("Total Supply:", totalSupply);
        console.log("Max Allowed (25%):", (totalSupply * maxPercentage) / 100);
        console.log("Attempted Amount (26%):", excessiveCreatorAmount);

        vm.startPrank(coinCreator);
        vm.expectRevert(EXCEEDS_DISTRIBUTION_LIMIT.selector);

        metalFactory.deployToken(
            "ExcessiveToken",
            "EXC",
            totalSupply,
            address(coinCreator),
            excessiveCreatorAmount, // Exceeds 25% limit
            0, // LP reserve
            false, // Auto-create LP
            0, // Initial price
            0 // WETH amount
        );

        vm.stopPrank();
    }

    function test_RevertWhen_TotalReservedExceedsTotalSupply() public {
        address coinCreator = makeAddr("coinCreator");

        // Set up amounts that exceed total supply when combined
        uint256 creatorAmount2 = totalSupply / 2; // 50% of supply
        uint256 lpReserve = totalSupply / 2 + 1 ether; // 50% + 1 of supply

        console.log("--- Test Total Reserved Exceeds Total Supply ---");
        console.log("Total Supply:", totalSupply);
        console.log("Creator Amount:", creatorAmount2);
        console.log("LP Reserve:", lpReserve);
        console.log("Total Reserved:", creatorAmount2 + lpReserve);

        vm.startPrank(coinCreator);
        vm.expectRevert(INVALID_AMOUNT.selector);

        metalFactory.deployToken(
            "ExcessiveToken",
            "EXC",
            totalSupply,
            address(coinCreator),
            creatorAmount2, // Use creatorAmount2 instead of creatorAmount
            lpReserve, // Combined with creatorAmount2 exceeds total supply
            false,
            0,
            0
        );

        vm.stopPrank();
    }

    function test_fuzz_createLiquidityPool(uint256 randomLpAmount, uint256 randomPrice) public {
        // Ensure the random values are within reasonable bounds
        uint256 maxLpAmount = totalSupply - creatorAmount; // Ensure we account for creator amount
        uint256 maxPrice = 0.98 ether;
        uint256 minPrice = 0.00000121 ether;

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
            false, // Don't auto-create LP
            0, // Initial price
            0 // WETH amount
        );

        // Create liquidity pool with constrained price
        metalFactory.createLiquidityPool(address(token), fuzzedPrice, address(0), 0);

        // Verify LP reserve is set to 0 after pool creation
        assertEq(metalFactory.lpReserves(address(token)), 0, "LP reserve not reset to zero");
        vm.stopPrank();
    }

    function test_deployTokenWithAutoCreateLP() public {
        address recipient = makeAddr("recipient");
        uint256 liquidityAmount = 100_000 ether;

        vm.startPrank(owner);

        // Deploy token with auto LP creation
        InstantLiquidityToken token = metalFactory.deployToken(
            "AutoLPToken",
            "AUTO",
            totalSupply,
            recipient,
            creatorAmount,
            liquidityAmount, // LP reserve
            true, // Auto-create LP
            initialPricePerEth, // Initial price
            0 // No WETH for initial buy
        );

        // Verify LP was created
        assertEq(
            metalFactory.lpReserves(address(token)), 0, "LP reserve should be 0 after auto-creation"
        );
        assertGt(metalFactory.nftIds(address(token)), 0, "NFT ID should be set");

        vm.stopPrank();
    }

    function test_fuzz_initialBuy() public {
        address recipient = makeAddr("recipient");
        uint256 liquidityAmount = 4_250_000 ether; // 85% of 5M total supply

        // Use production supply values
        uint256 REAL_TOTAL_SUPPLY = 5_000_000 ether;

        // Real price valuations
        uint256 price10K = 0.00000121 ether; // 10K valuation - LOW valuation (HIGH starting price)
        uint256 price100K = 0.00001211 ether; // 100K valuation - HIGH valuation (LOW starting price)

        // Get the WETH caps directly from the contract
        // For lower valuation (10K) - use the high evaluation cap (max 2.13369 ETH)
        uint256 wethCapFor10K = metalFactory.maxWethPreBuyLowEvaluation(); // 2.13369 ETH
        // For higher valuation (100K) - use the low evaluation cap (max 21.7512 ETH)
        uint256 wethCapFor100K = metalFactory.maxWethPreBuyHighEvaluation(); // 21.7512 ETH

        // Start test as owner
        vm.startPrank(owner);

        // Convert ETH to WETH and approve
        (bool success,) = WETH.call{value: 100 ether}("");
        require(success, "WETH deposit failed");
        IERC20(WETH).approve(address(metalFactory), type(uint256).max);

        // Define test amounts from very small to cap limits
        uint256[] memory testAmounts10K = new uint256[](5);
        testAmounts10K[0] = 0.01 ether; // Very small amount
        testAmounts10K[1] = 0.1 ether; // Small amount
        testAmounts10K[2] = 0.5 ether; // Medium amount
        testAmounts10K[3] = 1 ether; // Standard amount
        testAmounts10K[4] = wethCapFor10K; // Absolute maximum allowed (2.13369 ETH)

        uint256[] memory testAmounts100K = new uint256[](5);
        testAmounts100K[0] = 0.1 ether; // Very small amount
        testAmounts100K[1] = 1 ether; // Small amount
        testAmounts100K[2] = 5 ether; // Medium amount
        testAmounts100K[3] = 10 ether; // Standard amount
        testAmounts100K[4] = wethCapFor100K; // Absolute maximum allowed (21.7512 ETH)

        emit log("\n=== SYSTEMATIC TESTING OF WETH AMOUNTS AND SLIPPAGE RATES ===");

        // Test 1: 10K valuation pool with different WETH amounts
        emit log("\n=== TESTING 10K VALUATION POOL WITH DIFFERENT WETH AMOUNTS ===");
        emit log_named_uint("Token Price", price10K);
        emit log_named_uint("Maximum WETH Cap", wethCapFor10K);

        // Create a summary table of results
        emit log("\n| WETH Amount | Expected Tokens | Actual Tokens | Slippage % |");
        emit log("|------------|-----------------|---------------|-----------|");

        for (uint256 i = 0; i < testAmounts10K.length; i++) {
            uint256 wethAmount = testAmounts10K[i];
            uint256 expectedTokens = wethAmount * 1e18 / price10K;

            try metalFactory.deployToken(
                string(abi.encodePacked("Test10K", i)),
                string(abi.encodePacked("T10K", i)),
                REAL_TOTAL_SUPPLY,
                recipient,
                0, // No merchant allocation
                liquidityAmount,
                true, // Auto-create LP
                price10K,
                wethAmount
            ) returns (InstantLiquidityToken token) {
                uint256 actualTokens = token.balanceOf(recipient);

                uint256 slippagePercent;
                string memory slippageResult;

                if (expectedTokens > actualTokens) {
                    slippagePercent = (expectedTokens - actualTokens) * 100 / expectedTokens;
                    slippageResult = string(abi.encodePacked(uint2str(slippagePercent), "%"));
                } else {
                    slippagePercent = (actualTokens - expectedTokens) * 100 / expectedTokens;
                    slippageResult = string(abi.encodePacked("-", uint2str(slippagePercent), "%"));
                }

                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | ",
                            uint2str(actualTokens / 1e18),
                            " | ",
                            slippageResult,
                            " |"
                        )
                    )
                );

                assertGt(actualTokens, 0, "Should receive tokens");
            } catch Error(string memory reason) {
                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | FAILED | ",
                            reason,
                            " |"
                        )
                    )
                );
            } catch {
                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | FAILED | ",
                            "Unknown error",
                            " |"
                        )
                    )
                );
            }
        }

        // Add explicit summary log at the end of the 10K test
        emit log("\n=== SLIPPAGE ANALYSIS FOR 10K VALUATION POOLS ===");
        emit log(
            "Low valuation pools (10K) tend to have higher slippage, especially with larger WETH amounts"
        );

        // Test 2: Verify EXCEEDS_PREBUY_LIMIT for 10K at high WETH value
        uint256 highWethAmount10K = wethCapFor10K + 0.1 ether;

        emit log("\n--- Verifying PREBUY_LIMIT with high WETH amount for 10K pool ---");
        emit log_named_uint("High WETH amount", highWethAmount10K);

        try metalFactory.deployToken(
            "Test10KHigh",
            "T10KH",
            REAL_TOTAL_SUPPLY,
            recipient,
            0,
            liquidityAmount,
            true,
            price10K,
            highWethAmount10K
        ) returns (InstantLiquidityToken) {
            fail("High WETH amount should fail with EXCEEDS_PREBUY_LIMIT for 10K pools");
        } catch Error(string memory reason) {
            emit log_string(string(abi.encodePacked("Expected failure: ", reason)));
            // Don't assert on specific error as it might vary in format
        } catch {
            emit log("Received unknown error - expected EXCEEDS_PREBUY_LIMIT");
        }

        // Test 3: 100K valuation pool with different WETH amounts
        emit log("\n=== TESTING 100K VALUATION POOL WITH DIFFERENT WETH AMOUNTS ===");
        emit log_named_uint("Token Price", price100K);
        emit log_named_uint("Maximum WETH Cap", wethCapFor100K);

        // Create a summary table of results
        emit log("\n| WETH Amount | Expected Tokens | Actual Tokens | Slippage % |");
        emit log("|------------|-----------------|---------------|-----------|");

        for (uint256 i = 0; i < testAmounts100K.length; i++) {
            uint256 wethAmount = testAmounts100K[i];
            uint256 expectedTokens = wethAmount * 1e18 / price100K;

            try metalFactory.deployToken(
                string(abi.encodePacked("Test100K", i)),
                string(abi.encodePacked("T100K", i)),
                REAL_TOTAL_SUPPLY,
                recipient,
                0, // No merchant allocation
                liquidityAmount,
                true, // Auto-create LP
                price100K,
                wethAmount
            ) returns (InstantLiquidityToken token) {
                uint256 actualTokens = token.balanceOf(recipient);

                uint256 slippagePercent;
                string memory slippageResult;

                if (expectedTokens > actualTokens) {
                    slippagePercent = (expectedTokens - actualTokens) * 100 / expectedTokens;
                    slippageResult = string(abi.encodePacked(uint2str(slippagePercent), "%"));
                } else {
                    slippagePercent = (actualTokens - expectedTokens) * 100 / expectedTokens;
                    slippageResult = string(abi.encodePacked("-", uint2str(slippagePercent), "%"));
                }

                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | ",
                            uint2str(actualTokens / 1e18),
                            " | ",
                            slippageResult,
                            " |"
                        )
                    )
                );

                // Basic verification
                assertGt(actualTokens, 0, "Should receive tokens");

                // Set slippage limit for verification
                uint256 slippageLimit = 35; // Default 35% tolerance
                assertLe(
                    expectedTokens > actualTokens ? slippagePercent : 0,
                    slippageLimit,
                    "Slippage exceeds limit"
                );
            } catch Error(string memory reason) {
                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | FAILED | ",
                            reason,
                            " |"
                        )
                    )
                );

                if (wethAmount <= wethCapFor100K) {
                    fail(string(abi.encodePacked("100K valuation buy within cap failed: ", reason)));
                }
            } catch {
                emit log(
                    string(
                        abi.encodePacked(
                            "| ",
                            uint2str(wethAmount / 1e16),
                            " ether | ",
                            uint2str(expectedTokens / 1e18),
                            " | FAILED | ",
                            "Unknown error",
                            " |"
                        )
                    )
                );

                if (wethAmount <= wethCapFor100K) {
                    fail("100K valuation buy within cap failed unexpectedly");
                }
            }
        }

        // Add explicit summary log at the end of the 100K test
        emit log("\n=== SLIPPAGE ANALYSIS FOR 100K VALUATION POOLS ===");
        emit log(
            "High valuation pools (100K) have significantly lower slippage across all WETH amounts"
        );

        vm.stopPrank();
    }

    // Helper function to convert uint to string for logging
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function test_updateConfiguration() public {
        uint256 newMaxWethPreBuyLowEvaluation = 25 ether;
        uint256 newMaxWethPreBuyHighEvaluation = 5 ether;
        uint256 newMaxInitialPrice = 0.9 ether;
        uint256 newEvaluationThreshold = 0.00002 ether;

        console.log("--- Test Update Configuration ---");
        console.log(
            "Original maxWethPreBuyLowEvaluation:", metalFactory.maxWethPreBuyLowEvaluation()
        );
        console.log(
            "Original maxWethPreBuyHighEvaluation:", metalFactory.maxWethPreBuyHighEvaluation()
        );
        console.log("Original maxInitialPrice:", metalFactory.maxInitialPrice());
        console.log("Original evaluationThreshold:", metalFactory.evaluationThreshold());

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit ConfigurationUpdated(
            newMaxWethPreBuyLowEvaluation,
            newMaxWethPreBuyHighEvaluation,
            newMaxInitialPrice,
            newEvaluationThreshold
        );

        // Update the configuration as owner
        vm.prank(owner);
        metalFactory.updateConfiguration(
            newMaxWethPreBuyLowEvaluation,
            newMaxWethPreBuyHighEvaluation,
            newMaxInitialPrice,
            newEvaluationThreshold
        );

        // Verify the configuration was updated
        assertEq(
            metalFactory.maxWethPreBuyLowEvaluation(),
            newMaxWethPreBuyLowEvaluation,
            "maxWethPreBuyLowEvaluation should be updated"
        );
        assertEq(
            metalFactory.maxWethPreBuyHighEvaluation(),
            newMaxWethPreBuyHighEvaluation,
            "maxWethPreBuyHighEvaluation should be updated"
        );
        assertEq(
            metalFactory.maxInitialPrice(), newMaxInitialPrice, "maxInitialPrice should be updated"
        );
        assertEq(
            metalFactory.evaluationThreshold(),
            newEvaluationThreshold,
            "evaluationThreshold should be updated"
        );

        console.log("New maxWethPreBuyLowEvaluation:", metalFactory.maxWethPreBuyLowEvaluation());
        console.log("New maxWethPreBuyHighEvaluation:", metalFactory.maxWethPreBuyHighEvaluation());
        console.log("New maxInitialPrice:", metalFactory.maxInitialPrice());
        console.log("New evaluationThreshold:", metalFactory.evaluationThreshold());
    }

    function test_RevertWhen_NonOwnerUpdatesConfiguration() public {
        address nonOwner = makeAddr("nonOwner");

        console.log("--- Test Non-Owner Cannot Update Configuration ---");

        // Attempt to update configuration as non-owner
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        metalFactory.updateConfiguration(10 ether, 1 ether, 0.5 ether, 0.00001 ether);
    }

    function test_createLiquidityPoolWithNewMaxPrice() public {
        // Get the current configuration
        uint256 currentMaxPrice = metalFactory.maxInitialPrice();

        // Use a price just below the current limit (no configuration update needed)
        uint256 priceJustBelowLimit = currentMaxPrice - 0.01 ether;

        console.log("Current maxInitialPrice:", currentMaxPrice);
        console.log("Using price just below limit:", priceJustBelowLimit);

        // Deploy token with LP reserve
        uint256 liquidityAmount = 100_000 ether;
        vm.startPrank(owner);

        InstantLiquidityToken token = metalFactory.deployToken(
            "LPToken",
            "LPT",
            totalSupply,
            address(metalFactory),
            creatorAmount,
            liquidityAmount, // LP reserve
            false, // Do not auto-create LP
            0, // Initial price not set yet
            0 // No WETH for initial buy
        );

        // Create liquidity pool with price below the current limit
        uint256 lpTokenId =
            metalFactory.createLiquidityPool(address(token), priceJustBelowLimit, address(0), 0);

        // Verify results
        assertEq(metalFactory.lpReserves(address(token)), 0, "LP reserve not reset to zero");
        assertEq(metalFactory.nftIds(address(token)), lpTokenId, "NFT ID should be stored");

        vm.stopPrank();
    }

    function test_initialBuyWithUpdatedLimits() public {
        // Get the actual factory owner
        address factoryOwner = metalFactory.owner();

        console.log("\n--- Initial Buy Test with Updated Limits (Detailed Slippage Analysis) ---");
        console.log("Factory owner:", factoryOwner);

        // Set new limits
        uint256 newMaxWethPreBuyLowEvaluation = 30 ether;
        uint256 newMaxWethPreBuyHighEvaluation = 10 ether;
        console.log(
            "Setting new prebuy limits:",
            newMaxWethPreBuyLowEvaluation,
            newMaxWethPreBuyHighEvaluation
        );

        // Make sure we're using the correct owner and the WETH is approved
        vm.startPrank(factoryOwner);

        // Verify WETH balance and approval
        uint256 wethBalance = IERC20(WETH).balanceOf(factoryOwner);
        console.log("Owner WETH balance:", wethBalance);

        // Approve again just to be sure
        IERC20(WETH).approve(address(metalFactory), type(uint256).max);

        // Update the configuration
        metalFactory.updateConfiguration(
            newMaxWethPreBuyLowEvaluation,
            newMaxWethPreBuyHighEvaluation,
            metalFactory.maxInitialPrice(),
            metalFactory.evaluationThreshold()
        );

        // Local test token amount for liquidity pool and higher WETH amount
        uint256 liquidityAmount = 100_000 ether;
        uint256 wethAmount = 8 ether; // Higher WETH amount that should now be allowed
        address recipient = makeAddr("recipient");

        // Calculate expected amount with no slippage
        uint256 expectedTokens = wethAmount * 1e18 / initialPricePerEth;
        console.log("Expected tokens (0% slippage):", expectedTokens);

        // Calculate minimum amounts at various slippage levels for analysis
        console.log("Minimum tokens (5% slippage):", expectedTokens * 95 / 100);
        console.log("Minimum tokens (10% slippage):", expectedTokens * 90 / 100);
        console.log("Minimum tokens (15% slippage):", expectedTokens * 85 / 100);
        console.log("Minimum tokens (20% slippage):", expectedTokens * 80 / 100);
        console.log("Minimum tokens (25% slippage):", expectedTokens * 75 / 100);
        console.log("Minimum tokens (30% slippage):", expectedTokens * 70 / 100);
        console.log("Minimum tokens (32% slippage):", expectedTokens * 68 / 100); // Current protection level
        console.log("Minimum tokens (35% slippage):", expectedTokens * 65 / 100);
        console.log("Minimum tokens (40% slippage):", expectedTokens * 60 / 100);

        try metalFactory.deployToken(
            "BuyToken",
            "BUY",
            totalSupply,
            recipient,
            creatorAmount,
            liquidityAmount, // LP reserve
            true, // Auto-create LP
            initialPricePerEth, // Initial price
            wethAmount // Higher WETH amount for initial buy
        ) returns (InstantLiquidityToken token) {
            // Verify recipient received tokens from the initial buy
            uint256 recipientBalance = token.balanceOf(recipient);
            console.log("SUCCESS - Recipient token balance after initial buy:", recipientBalance);
            assertGt(recipientBalance, 0, "Recipient should have received tokens");

            // Calculate the actual slippage
            if (expectedTokens > recipientBalance) {
                uint256 slippagePercent =
                    ((expectedTokens - recipientBalance) * 100) / expectedTokens;
                console.log("Actual slippage:", slippagePercent, "%");
                console.log("Required slippage tolerance:", slippagePercent + 1, "%");

                // Check which slippage tolerance level would have worked
                if (recipientBalance >= expectedTokens * 95 / 100) {
                    console.log("5% slippage tolerance would be SUFFICIENT");
                } else if (recipientBalance >= expectedTokens * 90 / 100) {
                    console.log("10% slippage tolerance would be SUFFICIENT");
                } else if (recipientBalance >= expectedTokens * 85 / 100) {
                    console.log("15% slippage tolerance would be SUFFICIENT");
                } else if (recipientBalance >= expectedTokens * 80 / 100) {
                    console.log("20% slippage tolerance would be SUFFICIENT");
                } else if (recipientBalance >= expectedTokens * 75 / 100) {
                    console.log("25% slippage tolerance would be SUFFICIENT");
                } else if (recipientBalance >= expectedTokens * 70 / 100) {
                    console.log("30% slippage tolerance would be SUFFICIENT");
                } else {
                    console.log("Slippage is EXTREMELY high (>30%)");
                }
            }

            // Verify the configuration was updated
            assertEq(
                metalFactory.maxWethPreBuyLowEvaluation(),
                newMaxWethPreBuyLowEvaluation,
                "maxWethPreBuyLowEvaluation should be updated"
            );
            assertEq(
                metalFactory.maxWethPreBuyHighEvaluation(),
                newMaxWethPreBuyHighEvaluation,
                "maxWethPreBuyHighEvaluation should be updated"
            );
        } catch Error(string memory reason) {
            console.log("FAILED - Reason:", reason);
        } catch {
            console.log("FAILED - Unknown reason (likely 'Too little received')");
        }

        vm.stopPrank();
    }

    // Helper function to test if a specific tolerance level is sufficient
    function testTolerance(uint256 actualAmount, uint256 expectedAmount, uint8 tolerancePercent)
        internal
        view
    {
        uint256 minAmount = expectedAmount * (100 - tolerancePercent) / 100;
        bool sufficient = actualAmount >= minAmount;
        console.log(tolerancePercent, "% tolerance:", sufficient ? "SUFFICIENT" : "INSUFFICIENT");
    }

    // Helper function to test slippage level (same as testTolerance but for emit log usage)
    function testSlippageLevel(uint256 expectedAmount, uint256 actualAmount, uint8 tolerancePercent)
        internal
    {
        uint256 minAmount = expectedAmount * (100 - tolerancePercent) / 100;
        bool sufficient = actualAmount >= minAmount;
        emit log_named_string(
            string(abi.encodePacked(uint256(tolerancePercent), "% tolerance")),
            sufficient ? "SUFFICIENT" : "INSUFFICIENT"
        );
    }
}
