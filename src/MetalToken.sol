// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {POOL_FEE} from "./Constants.sol";
import {calculatePrices} from "./lib/priceCalc.sol";
import {InstantLiquidityToken} from "./InstantLiquidityToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

// Custom errors
error INVALID_AMOUNT();
error UNSUPPORTED_CHAIN();
error PRICE_TOO_HIGH();
error EXCEEDS_LP_RESERVE();
error INVALID_MERCHANT_ADDRESS();
error INVALID_SIGNER();

// NonfungiblePositionManager interface
interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function collect(CollectParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);
}

contract MetalToken is Ownable, ERC721Holder {
    struct Storage {
        uint96 deploymentNonce;
        InstantLiquidityToken instantLiquidityToken;
    }

    // Mappings
    mapping(address => uint256) public lpReserves;

    // State variables
    Storage public s = Storage({
        deploymentNonce: 0,
        instantLiquidityToken: InstantLiquidityToken(0xD74D14ebe305c93D023C966640788f05593F0fdE)
    });

    // Events
    event TokenDeployment(
        address indexed token,
        address indexed recipient,
        string name,
        string symbol,
        bool hasLiquidity,
        uint256 lpReserve
    );

    event TokenDeployed(string name, string symbol, uint256 totalSupply, uint256 initialPrice);

    event LiquidityPoolCreated(
        address indexed tokenAddress, uint256 totalAmount, uint256 nftId, address poolAddress
    );

    event FeesCollected(address indexed recipient, uint256 indexed nftId);

    constructor(address _owner) Ownable(_owner) {
        uint256 chainId = block.chainid;
        if (
            chainId != 1 // mainnet
                && chainId != 5 // goerli
                && chainId != 42161 // arbitrum
                && chainId != 10 // optimism
                && chainId != 137 // polygon
                && chainId != 56 // bnb
                && chainId != 8453 // base
                && chainId != 84532 // base sepolia
                && chainId != 11155111 // sepolia
                && chainId != 7777777 // zora
                && chainId != 666666666 // degen chain
        ) revert UNSUPPORTED_CHAIN();
    }

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
            fee: 10_000,
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
     * @param _merchant Address to receive merchant allocation
     * @param _merchantAmount Amount for merchant
     * @param _lpReserve Amount for liquidity pool
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _merchant,
        uint256 _merchantAmount,
        uint256 _lpReserve,
        uint256 _airdropReserve,
        uint256 _rewardsReserve
    ) external returns (InstantLiquidityToken token) {
        address signer = msg.sender;
        address tokenAddress;
        // Validate total amounts
        uint256 totalReserved = _merchantAmount + _lpReserve + _airdropReserve + _rewardsReserve;
        if (totalReserved > _totalSupply) revert INVALID_AMOUNT();

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

        token = InstantLiquidityToken(tokenAddress);

        if (_merchant == address(0)) revert INVALID_MERCHANT_ADDRESS();
        if (signer == address(0)) revert INVALID_SIGNER();

        // Handle merchant transfer if needed
        if (_merchantAmount > 0) {
            merchantTransfer(address(token), _merchant, _merchantAmount);
        }

        // Handle airdropReserve transfer if needed
        if (_airdropReserve > 0) {
            merchantTransfer(address(token), signer, _airdropReserve);
        }

        // Handle rewardsReserve transfer if needed
        if (_rewardsReserve > 0) {
            merchantTransfer(address(token), signer, _rewardsReserve);
        }

        emit TokenDeployment(address(token), _merchant, _name, _symbol, _lpReserve > 0, _lpReserve);

        return token;
    }

    /**
     * @dev Transfers tokens to a merchant
     * @param _token Token address
     * @param _merchant Recipient address
     * @param _amount Amount to transfer
     */
    function merchantTransfer(address _token, address _merchant, uint256 _amount)
        public
        onlyOwner
    {
        if (_amount == 0) revert INVALID_AMOUNT();

        InstantLiquidityToken(_token).transfer(_merchant, _amount);
    }

    /**
     * @dev Creates a liquidity pool for a token
     * @param _token Token address
     * @param _initialPricePerEth Initial price in ETH
     * @return lpTokenId ID of the LP position NFT
     */
    function createLiquidityPool(address _token, uint256 _initialPricePerEth)
        public
        onlyOwner
        returns (uint256 lpTokenId)
    {
        if (_initialPricePerEth > 0.98 ether) revert PRICE_TOO_HIGH();

        // Retrieve lpReserve from the mapping
        uint256 lpAmount = lpReserves[_token];
        if (lpAmount == 0) revert INVALID_AMOUNT();

        (address weth, INonfungiblePositionManager positionManager) = _getAddresses();

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

        emit LiquidityPoolCreated(_token, liquidity, lpTokenId, poolAddress);

        return lpTokenId;
    }

    /**
     * @dev Collects fees from LP positions
     * @param recipient Address to receive the fees
     * @param tokenIds Array of LP position NFT IDs
     */
    function collectFees(address recipient, uint256[] memory tokenIds) public onlyOwner {
        (, INonfungiblePositionManager positionManager) = _getAddresses();

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
     * @dev Returns the chain-specific addresses for WETH and NonFungiblePositionManager
     * @notice This function returns different addresses based on the current chain:
     */
    function _getAddresses()
        internal
        view
        returns (address weth, INonfungiblePositionManager nonFungiblePositionManager)
    {
        uint256 chainId = block.chainid;
        // Mainnet, Goerli, Arbitrum, Optimism, Polygon
        nonFungiblePositionManager =
            INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

        // mainnet
        if (chainId == 1) weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        // goerli
        if (chainId == 5) weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
        // arbitrum
        if (chainId == 42161) weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        // optimism
        if (chainId == 10) weth = 0x4200000000000000000000000000000000000006;
        // polygon
        if (chainId == 137) weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        // bnb
        if (chainId == 56) {
            weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            nonFungiblePositionManager =
                INonfungiblePositionManager(0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613);
        }
        // base
        if (chainId == 8453) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager =
                INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
        }
        // base sepolia
        if (chainId == 84532) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager =
                INonfungiblePositionManager(0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2);
        }
        // sepolia
        if (chainId == 11155111) {
            weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
            nonFungiblePositionManager =
                INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
        }
        // zora
        if (chainId == 7777777) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager =
                INonfungiblePositionManager(0xbC91e8DfA3fF18De43853372A3d7dfe585137D78);
        }
        // degen chain
        if (chainId == 666666666) {
            // wrapped degen
            weth = 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387;
            nonFungiblePositionManager =
            // proxy swap
             INonfungiblePositionManager(0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f);
        }
    }
}
