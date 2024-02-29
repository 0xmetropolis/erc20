// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LIQUIDITY_TOKEN_SALT, POOL_AMOUNT} from "src/Constants.sol";
import {InstantLiquidityToken} from "src/InstantLiquidityToken.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

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

    function mint(MintParams calldata params)
        external
        payable
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        returns (address pool);
}

contract TokenFactory {
    error UNSUPPORTED_CHAIN();

    InstantLiquidityToken public immutable instantLiquidityToken =
        new InstantLiquidityToken{salt: LIQUIDITY_TOKEN_SALT}();

    constructor() {
        uint256 chainId = block.chainid;
        if (
            // mainnet
            chainId != 1
            // goerli
            && chainId != 5
            // arbitrum
            && chainId != 42161
            // optimism
            && chainId != 10
            // polygon
            && chainId != 137
            // bnb
            && chainId != 56
            // base
            && chainId != 8453
            // base sepolia
            && chainId != 84532
            // sepolia
            && chainId != 11155111
        ) revert UNSUPPORTED_CHAIN();
    }

    /**
     * @dev sourced from: https://docs.uniswap.org/contracts/v3/reference/deployments
     */
    function _getAddresses()
        internal
        view
        returns (address weth, INonfungiblePositionManager nonFungiblePositionManager)
    {
        uint256 chainId = block.chainid;
        // Mainnet, Goerli, Arbitrum, Optimism, Polygon
        nonFungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

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
            nonFungiblePositionManager = INonfungiblePositionManager(0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613);
        }
        // base
        if (chainId == 8453) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
        }
        // base sepolia
        if (chainId == 84532) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2);
        }
        // sepolia
        if (chainId == 11155111) {
            weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
            nonFungiblePositionManager = INonfungiblePositionManager(0x1238536071E1c677A632429e3655c799b22cDA52);
        }
    }

    function _getMintParams(address token, address weth)
        internal
        view
        returns (INonfungiblePositionManager.MintParams memory params, uint160 initialSqrtPrice)
    {
        bool tokenIsLessThanWeth = token < weth;
        (address token0, address token1) = tokenIsLessThanWeth ? (token, weth) : (weth, token);
        (int24 tickLower, int24 tickUpper) = tokenIsLessThanWeth ? (-68128, int24(184216)) : (-184217, int24(68127));
        (uint256 amt0, uint256 amt1) =
            tokenIsLessThanWeth ? (uint256(9999999999999999999999999986), uint256(0)) : (uint256(0), uint256(9999999999999999999999999981));

        params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: 100,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amt0,
            amount0Min: amt0,
            amount1Desired: amt1,
            amount1Min: amt1,
            deadline: block.timestamp,
            recipient: address(this)
        });

        initialSqrtPrice = tokenIsLessThanWeth ? 2505290050365003892876723467 : 2505413655765166104103837312489;
    }

    function deploy(string memory _name, string memory _symbol) public returns (InstantLiquidityToken) {
        // get the addresses per-chain
        (address weth, INonfungiblePositionManager nonfungiblePositionManager) = _getAddresses();

        // deploy and initialize a new token
        address token = Clones.clone(address(instantLiquidityToken));
        InstantLiquidityToken(token).initialize(msg.sender, _name, _symbol);

        // sort the tokens and the amounts
        (address token0, address token1) = token < weth ? (token, weth) : (weth, token);

        // approve the non-fungible position mgr for the pool liquidity amount
        InstantLiquidityToken(token).approve(address(nonfungiblePositionManager), POOL_AMOUNT);
        (INonfungiblePositionManager.MintParams memory mintParams, uint160 initialSquareRootPrice) =
            _getMintParams(token, weth);

        // create the pool
        nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, 100, initialSquareRootPrice);

        // mint the position
        nonfungiblePositionManager.mint(mintParams);

        return InstantLiquidityToken(token);
    }
}