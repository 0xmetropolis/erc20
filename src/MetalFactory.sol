// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {POOL_FEE} from "./Constants.sol";
import {calculatePrices} from "./lib/priceCalc.sol";
import {InstantLiquidityToken} from "./InstantLiquidityToken.sol";
import {
    getNetworkAddresses,
    INonfungiblePositionManager,
    ISwapRouter
} from "./lib/networkAddresses.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom errors
error INVALID_AMOUNT();
error UNSUPPORTED_CHAIN();
error PRICE_TOO_HIGH();
error EXCEEDS_LP_RESERVE();
error INVALID_SIGNER();
error NOT_TOKEN_DEPLOYER();
error EXCEEDS_DISTRIBUTION_LIMIT();
error EXCEEDS_PREBUY_LIMIT();

contract MetalFactory is Ownable, ERC721Holder {
    struct Storage {
        uint96 deploymentNonce;
        InstantLiquidityToken instantLiquidityToken;
    }

    // Mappings
    mapping(address => uint256) public lpReserves;
    mapping(address => address) public tokenDeployer;
    mapping(address => uint256) public nftIds;

    // State variables
    Storage public s = Storage({
        deploymentNonce: 0,
        instantLiquidityToken: InstantLiquidityToken(0xD74D14ebe305c93D023C966640788f05593F0fdE)
    });

    // Constants for limiting distribution and prebuy amounts
    uint256 public constant MAX_DISTRIBUTION_PERCENTAGE = 25;
    uint256 public constant MAX_PREBUY_PERCENTAGE = 25;
    uint256 public constant PERCENTAGE_DENOMINATOR = 100;

    uint256 public maxWethPreBuyHighEvaluation = 21.7512 ether;
    uint256 public maxWethPreBuyLowEvaluation = 2.13369 ether;
    uint256 public maxInitialPrice = 0.98 ether;
    uint256 public evaluationThreshold = 0.00001 ether;

    // modifiers
    modifier onlyTokenDeployer(address token) {
        if (tokenDeployer[token] != msg.sender) revert NOT_TOKEN_DEPLOYER();
        _;
    }

    // Events
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

    constructor(address _owner) Ownable(_owner) {
        uint256 chainId = block.chainid;
        if (
            chainId != 1 // mainnet
                && chainId != 42161 // arbitrum
                && chainId != 10 // optimism
                && chainId != 8453 // base
                && chainId != 84532 // base sepolia
                && chainId != 11155111 // sepolia
                && chainId != 7777777 // zora
        ) revert UNSUPPORTED_CHAIN();

        // Pre-approve WETH spending for the swap router
        (address weth,, ISwapRouter swapRouter) = getNetworkAddresses();
        if (address(swapRouter) != address(0)) {
            IERC20(weth).approve(address(swapRouter), type(uint256).max);
        }
    }

    /**
     * @dev Deploys a new token with optional LP creation and distribution
     * @param token Token address
     * @param weth WETH address
     * @param initialPricePerEth Initial price in ETH for auto LP creation
     * @param liquidityIn Amount for liquidity pool
     * @return params Mint parameters
     * @return initialSqrtPrice Initial square root price
     */
    function _getMintParams(
        address token,
        address weth,
        uint256 initialPricePerEth,
        uint256 liquidityIn
    )
        internal
        view
        returns (INonfungiblePositionManager.MintParams memory params, uint160 initialSqrtPrice)
    {
        bool tokenIsLessThanWeth = token < weth;

        (address token0, address token1) = tokenIsLessThanWeth ? (token, weth) : (weth, token);
        (uint160 sqrtPrice, int24 tickLower, int24 tickUpper) =
            calculatePrices(token, weth, initialPricePerEth);

        (uint256 amt0, uint256 amt1) = tokenIsLessThanWeth
            ? (uint256(liquidityIn), uint256(0))
            : (uint256(0), uint256(liquidityIn));

        params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amt0,
            amount0Min: amt0 - (amt0 / 1e8),
            amount1Desired: amt1,
            amount1Min: amt1 - (amt1 / 1e8),
            deadline: block.timestamp,
            recipient: address(this)
        });

        initialSqrtPrice = sqrtPrice;
    }

    /**
     * @dev Deploys a new token with optional LP creation and distribution
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _totalSupply Total supply of tokens
     * @param _recipient Address to receive token allocation
     * @param _distributionAmount Amount for recipient
     * @param _lpReserve Amount for liquidity pool
     * @param _autoCreateLP Flag to automatically create liquidity pool upon token deployment
     * @param _initialPricePerEth Initial price in ETH for auto LP creation (only used if _autoCreateLP is true)
     * @param _wethAmount Amount of WETH to use for initial buy (0 if no initial buy)
     * @return token The deployed token instance
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _recipient,
        uint256 _distributionAmount,
        uint256 _lpReserve,
        bool _autoCreateLP,
        uint256 _initialPricePerEth,
        uint256 _wethAmount
    ) external returns (InstantLiquidityToken token) {
        address signer = msg.sender;
        if (signer == address(0)) revert INVALID_SIGNER();

        address tokenAddress;
        // Validate total amounts
        uint256 totalReserved = _distributionAmount + _lpReserve;
        if (totalReserved > _totalSupply) revert INVALID_AMOUNT();

        // Check distribution amount doesn't exceed the limit
        if (
            _distributionAmount
                > (_totalSupply * MAX_DISTRIBUTION_PERCENTAGE) / PERCENTAGE_DENOMINATOR
        ) {
            revert EXCEEDS_DISTRIBUTION_LIMIT();
        }

        {
            Storage memory store = s;
            tokenAddress = Clones.cloneDeterministic(
                address(store.instantLiquidityToken),
                keccak256(abi.encode(block.chainid, store.deploymentNonce))
            );
            InstantLiquidityToken(tokenAddress).initialize({
                _mintTo: address(this),
                _totalSupply: _totalSupply,
                _name: _name,
                _symbol: _symbol
            });
            s.deploymentNonce += 1;
        }

        lpReserves[tokenAddress] = _lpReserve;
        tokenDeployer[tokenAddress] = signer;

        token = InstantLiquidityToken(tokenAddress);

        // Handle distributionAmount transfer to the recipient
        if (_distributionAmount > 0) {
            InstantLiquidityToken(token).transfer(_recipient, _distributionAmount);
        }

        // If auto-creating LP and there's a reserve for it, create the LP immediately
        if (_autoCreateLP) {
            createLiquidityPool(tokenAddress, _initialPricePerEth, _recipient, _wethAmount);
        }

        emit TokenDeployment(address(token), _recipient, _name, _symbol, _lpReserve > 0, _lpReserve);

        return token;
    }

    /**
     * @dev Creates a liquidity pool for a token and stores the NFT ID for future reference
     * @param _token Token address
     * @param _initialPricePerEth Initial price in ETH
     * @param _recipient Address to receive tokens from initial buy (if any)
     * @param _wethAmount Amount of WETH to use for initial buy (0 if no initial buy)
     * @return lpTokenId ID of the LP position NFT
     */
    function createLiquidityPool(
        address _token,
        uint256 _initialPricePerEth,
        address _recipient,
        uint256 _wethAmount
    ) public onlyTokenDeployer(_token) returns (uint256 lpTokenId) {
        if (_initialPricePerEth > maxInitialPrice) revert PRICE_TOO_HIGH();
        if (_initialPricePerEth == 0) revert INVALID_AMOUNT();

        // Retrieve lpReserve from the mapping
        uint256 lpAmount = lpReserves[_token];
        if (lpAmount == 0) revert INVALID_AMOUNT();

        (address weth, INonfungiblePositionManager positionManager,) = getNetworkAddresses();

        InstantLiquidityToken(_token).approve(address(positionManager), lpAmount);

        (INonfungiblePositionManager.MintParams memory mintParams, uint160 initialSquareRootPrice) =
        _getMintParams({
            token: _token,
            weth: weth,
            initialPricePerEth: _initialPricePerEth,
            liquidityIn: lpAmount
        });

        address token0 = _token < weth ? _token : weth;
        address token1 = _token < weth ? weth : _token;

        address poolAddress = positionManager.createAndInitializePoolIfNecessary({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            sqrtPriceX96: initialSquareRootPrice
        });

        // Liquidity amount after initialization
        uint256 liquidity;

        (lpTokenId, liquidity,,) = positionManager.mint({params: mintParams});

        lpReserves[_token] = 0;

        // Store NFT ID for future fee collection reference
        nftIds[_token] = lpTokenId;

        emit LiquidityPoolCreated(_token, liquidity, lpTokenId, poolAddress);

        // Perform initial buy if WETH amount is provided
        if (_wethAmount > 0 && _recipient != address(0)) {
            // Select the appropriate max WETH amount
            uint256 maxWethAmount = _initialPricePerEth >= evaluationThreshold
                ? maxWethPreBuyHighEvaluation
                : maxWethPreBuyLowEvaluation;

            // Ensure WETH amount doesn't exceed the maximum
            if (_wethAmount > maxWethAmount) {
                revert EXCEEDS_PREBUY_LIMIT();
            }

            uint256 amountTokensBought =
                _initialBuy(_token, _recipient, _wethAmount, _initialPricePerEth);

            // Emit event for the initial buy
            emit InitialBuyExecuted(_token, _recipient, _wethAmount, amountTokensBought);
        }

        return lpTokenId;
    }

    /**
     * @dev Executes an initial token purchase with WETH
     * @param token Token address to buy
     * @param recipient Address to receive the purchased tokens
     * @param wethAmount Amount of WETH to use for the purchase
     * @param _initialPricePerEth Initial price per ETH used to calculate minimum output
     * @return amountTokensBought Amount of tokens purchased
     */
    function _initialBuy(
        address token,
        address recipient,
        uint256 wethAmount,
        uint256 _initialPricePerEth
    ) internal returns (uint256 amountTokensBought) {
        // Get WETH address and swap router from network addresses
        (address weth,, ISwapRouter swapRouter) = getNetworkAddresses();

        // Transfer WETH from the sender to MetalFactory
        IERC20(weth).transferFrom(msg.sender, address(this), wethAmount);

        // Swap directly from WETH to the token
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: weth,
            tokenOut: token,
            fee: POOL_FEE,
            recipient: recipient,
            amountIn: wethAmount,
            amountOutMinimum: wethAmount * 1e18 / _initialPricePerEth * 68 / 100,
            sqrtPriceLimitX96: 0
        });

        // Execute swap and return the amount bought
        amountTokensBought = swapRouter.exactInputSingle(swapParams);

        return amountTokensBought;
    }

    /**
     * @dev Collects fees from LP positions
     * @param recipient Address to receive the fees
     * @param tokenIds Array of LP position NFT IDs
     */
    function collectFees(address recipient, uint256[] memory tokenIds) public onlyOwner {
        (, INonfungiblePositionManager positionManager,) = getNetworkAddresses();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: recipient,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: tokenIds[i]
                })
            );

            emit FeesCollected(recipient, tokenIds[i]);
        }
    }

    /**
     * @dev Updates the configurable values
     * @param _maxWethPreBuyLowEvaluation New max WETH prebuy for low evaluation
     * @param _maxWethPreBuyHighEvaluation New max WETH prebuy for high evaluation
     * @param _maxInitialPrice New maximum initial price
     * @param _evaluationThreshold New threshold for high/low evaluation determination
     */
    function updateConfiguration(
        uint256 _maxWethPreBuyLowEvaluation,
        uint256 _maxWethPreBuyHighEvaluation,
        uint256 _maxInitialPrice,
        uint256 _evaluationThreshold
    ) external onlyOwner {
        maxWethPreBuyLowEvaluation = _maxWethPreBuyLowEvaluation;
        maxWethPreBuyHighEvaluation = _maxWethPreBuyHighEvaluation;
        maxInitialPrice = _maxInitialPrice;
        evaluationThreshold = _evaluationThreshold;

        emit ConfigurationUpdated(
            maxWethPreBuyLowEvaluation,
            maxWethPreBuyHighEvaluation,
            maxInitialPrice,
            evaluationThreshold
        );
    }
}
