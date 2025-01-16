// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {POOL_FEE} from "./Constants.sol";
import {calculatePrices} from "./lib/priceCalc.sol";
import {InstantLiquidityToken} from "./InstantLiquidityToken.sol";
import {getNetworkAddresses, INonfungiblePositionManager} from "./lib/networkAddresses.sol";
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
     * @param _creator Address to receive merchant allocation
     * @param _creatorAmount Amount for merchant
     * @param _lpReserve Amount for liquidity pool
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        uint256 _totalSupply,
        address _creator,
        uint256 _creatorAmount,
        uint256 _lpReserve,
        uint256 _airdropReserve,
        uint256 _rewardsReserve
    ) external returns (InstantLiquidityToken token) {
        address signer = msg.sender;
        address tokenAddress;
        // Validate total amounts
        uint256 totalReserved = _creatorAmount + _lpReserve + _airdropReserve + _rewardsReserve;
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

        if (_creator == address(0)) revert INVALID_MERCHANT_ADDRESS();
        if (signer == address(0)) revert INVALID_SIGNER();

        // Handle merchant transfer if needed
        if (_creatorAmount > 0) {
            merchantTransfer(address(token), _creator, _creatorAmount);
        }

        // Handle airdropReserve transfer if needed
        if (_airdropReserve > 0) {
            merchantTransfer(address(token), signer, _airdropReserve);
        }

        // Handle rewardsReserve transfer if needed
        if (_rewardsReserve > 0) {
            merchantTransfer(address(token), signer, _rewardsReserve);
        }

        // lpReserve remains on the factory until createLiquidityPool is called  

        emit TokenDeployment(address(token), _creator, _name, _symbol, _lpReserve > 0, _lpReserve);

        return token;
    }

    /**
     * @dev Transfers tokens to a merchant
     * @param _token Token address
     * @param _creator Recipient address
     * @param _amount Amount to transfer
     */
    function merchantTransfer(address _token, address _creator, uint256 _amount)
        public
        onlyOwner
    {
        if (_amount == 0) revert INVALID_AMOUNT();

        InstantLiquidityToken(_token).transfer(_creator, _amount);
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

        (address weth, INonfungiblePositionManager positionManager) = getNetworkAddresses();

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
        (, INonfungiblePositionManager positionManager) = getNetworkAddresses();

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
}
