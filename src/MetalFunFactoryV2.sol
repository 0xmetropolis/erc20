// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {POOL_FEE} from "./Constants.sol";
import {calculatePrices} from "./lib/priceCalc.sol";
import {getAddresses} from "./lib/addresses.sol";
import {InstantLiquidityToken} from "./InstantLiquidityToken.sol";
import {INonfungiblePositionManager} from "./TokenFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract MetalFunFactoryV2 is Ownable, ERC721Holder {
    error UNSUPPORTED_CHAIN();
    error INVALID_RECIPIENT_AMOUNT();
    error PRICE_TOO_HIGH();

    event TokenFactoryDeployment(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol
    );

    struct Storage {
        // a nonce to ensure unique token ids for each deployment.
        uint96 deploymentNonce;
        // the instant liquidity token contract.
        InstantLiquidityToken instantLiquidityToken;
    }

    Storage public s = Storage({
        deploymentNonce: 0,
        instantLiquidityToken: InstantLiquidityToken(0xD74D14ebe305c93D023C966640788f05593F0fdE)
    });

    constructor(address _owner) Ownable(_owner) {
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
            // zora
            && chainId != 7777777
            // degen chain
            && chainId != 666666666
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
            // 1% fee
            fee: 10_000,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amt0,
            // allow for a bit of slippage
            amount0Min: amt0 - (amt0 / 1e8),
            amount1Desired: amt1,
            amount1Min: amt1 - (amt1 / 1e8),
            deadline: block.timestamp,
            recipient: address(this)
        });

        initialSqrtPrice = sqrtPrice;
    }

    function _deploy(
        string memory _name,
        string memory _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        address _recipient,
        uint256 _recipientAmount
    ) internal returns (InstantLiquidityToken, uint256) {
        // get the addresses per-chain
        (address weth, INonfungiblePositionManager nonfungiblePositionManager) = getAddresses();
        address token;
        {
            Storage memory store = s;
            // deploy and initialize a new token
            token = Clones.cloneDeterministic(
                address(store.instantLiquidityToken),
                keccak256(abi.encode(block.chainid, store.deploymentNonce))
            );
            InstantLiquidityToken(token).initialize({
                _mintTo: address(this),
                _totalSupply: _totalSupply,
                _name: _name,
                _symbol: _symbol
            });
            s.deploymentNonce += 1;
        }

        uint256 poolAmount = _totalSupply - _recipientAmount;
        // approve the non-fungible position mgr for the pool liquidity amount
        InstantLiquidityToken(token).approve({
            spender: address(nonfungiblePositionManager),
            value: poolAmount
        });

        (INonfungiblePositionManager.MintParams memory mintParams, uint160 initialSquareRootPrice) =
        _getMintParams({
            token: token,
            weth: weth,
            initialPricePerEth: _initialPricePerEth,
            liquidityIn: poolAmount
        });

        // create the pool
        nonfungiblePositionManager.createAndInitializePoolIfNecessary({
            token0: token < weth ? token : weth,
            token1: token < weth ? weth : token,
            fee: POOL_FEE,
            sqrtPriceX96: initialSquareRootPrice
        });

        // mint the position
        (uint256 lpTokenId,,,) = nonfungiblePositionManager.mint({params: mintParams});

        // After token initialization and pool creation, transfer the recipient amount
        if (_recipientAmount > 0) {
            InstantLiquidityToken(token).transfer(_recipient, _recipientAmount);
        }

        return (InstantLiquidityToken(token), lpTokenId);
    }

    function deploy(
        string memory _name,
        string memory _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        address _recipient,
        uint256 _recipientAmount
    ) public returns (InstantLiquidityToken token, uint256 lpTokenId) {
        // recipient amount must be less or equal to the total supply
        if (_recipientAmount > _totalSupply) revert INVALID_RECIPIENT_AMOUNT();
        // the initial price must be at least 2% less than 1 eth
        if (_initialPricePerEth > 0.98 ether) revert PRICE_TOO_HIGH();

        (token, lpTokenId) =
            _deploy(_name, _symbol, _initialPricePerEth, _totalSupply, _recipient, _recipientAmount);

        emit TokenFactoryDeployment(address(token), lpTokenId, msg.sender, _name, _symbol);
    }

    function collectFees(address _recipient, uint256[] memory _tokenIds) public onlyOwner {
        (, INonfungiblePositionManager nonfungiblePositionManager) = getAddresses();

        for (uint256 i; i < _tokenIds.length; ++i) {
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: _recipient,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: _tokenIds[i]
                })
            );
        }
    }

    function setInstantLiquidityToken(address _instantLiquidityToken) public onlyOwner {
        s.instantLiquidityToken = InstantLiquidityToken(_instantLiquidityToken);
    }
}
