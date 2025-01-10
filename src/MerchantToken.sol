// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MerchantFactory.sol";
import {console} from "../lib/forge-std/src/console.sol"; //TODO: Remove after testing

// Interface for GasliteDrop
interface IGasliteDrop {
    function airdropERC20(
        address _token,
        address[] calldata _addresses,
        uint256[] calldata _amounts,
        uint256 _totalAmount
    ) external payable;
}

// Custom errors
error INVALID_AMOUNT();
error UNAUTHORIZED();
error INVALID_ADDRESS();

contract MerchantToken is MerchantFactory {
    // State variables
    address public maintenanceAddress; // Add a Metal owned address
    IGasliteDrop constant gasliteDrop = IGasliteDrop(0x09350F89e2D7B6e96bA730783c2d76137B045FEF);

    // Modifiers
    modifier onlyTokenOwnerOrMaintenance() {
        if (msg.sender != owner() && msg.sender != maintenanceAddress) {
            revert UNAUTHORIZED();
        }
        _;
    }

    modifier onlyMaintenance() {
        if (msg.sender != maintenanceAddress) {
            revert UNAUTHORIZED();
        }
        _;
    }

    // Events
    event TokenDeployment(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol,
        bool hasLiquidity,
        bool hasDistributionDrop
    );

    event TokenDeployed(string name, string symbol, uint256 totalSupply, uint256 initialPrice);

    event LiquidityPoolCreated(
        address indexed tokenAddress, uint256 totalAmount, uint256 nftId, address poolAddress
    );

    event DistributionDropExecuted(
        address indexed tokenAddress, uint256 totalAmount, address[] recipients
    );

    event FeesCollected(address indexed recipient, uint256 indexed nftId);

    constructor(address _owner, address _maintenanceAddress) MerchantFactory(_owner) {
        maintenanceAddress = _maintenanceAddress;
    }

    /**
     * @dev Deploys a new token with optional LP creation and distribution
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _initialPricePerEth Initial price in ETH
     * @param _totalSupply Total supply of tokens
     * @param _merchant Address to receive merchant allocation
     * @param _merchantAmount Amount for merchant
     * @param _lpAmount Amount for liquidity pool
     * @param _distroAmount Amount for distribution
     * @param _distroRecipients Array of distribution recipients
     */
    function deployToken(
        string memory _name,
        string memory _symbol,
        uint256 _initialPricePerEth,
        uint256 _totalSupply,
        address _merchant,
        uint256 _merchantAmount,
        uint256 _lpAmount,
        uint256 _distroAmount,
        address[] calldata _distroRecipients
    ) external onlyTokenOwnerOrMaintenance returns (InstantLiquidityToken token) {
        address tokenAddress;
        {
            Storage memory store = s;
            tokenAddress = Clones.cloneDeterministic(
                address(store.instantLiquidityToken),
                keccak256(abi.encode(block.chainid, store.deploymentNonce))
            );
            InstantLiquidityToken(tokenAddress).initialize({
                _mintTo: address(this), //TODO: Determine who should be the mintTo
                _totalSupply: _totalSupply,
                _name: _name,
                _symbol: _symbol
            });
            s.deploymentNonce += 1;
        }

        token = InstantLiquidityToken(tokenAddress);

        // Validate total amounts
        if (_merchantAmount + _lpAmount + _distroAmount > _totalSupply) {
            revert INVALID_AMOUNT();
        }

        // Handle merchant transfer if needed
        if (_merchantAmount > 0) {
            merchantTransfer(address(token), _merchant, _merchantAmount);
        }

        // Handle LP creation if needed
        uint256 lpTokenId;
        if (_lpAmount > 0) {
            lpTokenId = createLiquidityPool(address(token), _lpAmount, _initialPricePerEth);
        }

        // Handle distribution if needed
        if (_distroAmount > 0 && _distroRecipients.length > 0) {
            if (_distroAmount / _distroRecipients.length == 0) revert INVALID_AMOUNT();
            distributeTokens(address(token), _distroAmount, _distroRecipients);
        }

        // Emit single deployment event
        emit TokenDeployment(
            address(token), lpTokenId, _merchant, _name, _symbol, _lpAmount > 0, _distroAmount > 0
        );

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
        onlyTokenOwnerOrMaintenance
    {
        if (_amount == 0) revert INVALID_AMOUNT();

        InstantLiquidityToken(_token).transfer(_merchant, _amount);
    }

    /**
     * @dev Distributes tokens to multiple recipients using GasliteDrop
     * @param _token Token address
     * @param _distroAmount Total amount to distribute
     * @param _distroRecipients Array of recipient addresses
     */
    function distributeTokens(
        address _token,
        uint256 _distroAmount,
        address[] calldata _distroRecipients
    ) public onlyTokenOwnerOrMaintenance {
        // Input validations
        // Calculate amounts array
        // Approve gasliteDrop to spend tokens

        emit DistributionDropExecuted(_token, _distroAmount, _distroRecipients);
    }

    /**
     * @dev Creates a liquidity pool for a token
     * @param _token Token address
     * @param _lpAmount Amount of tokens for liquidity
     * @param _initialPricePerEth Initial price in ETH
     * @return lpTokenId ID of the LP position NFT
     */
    function createLiquidityPool(address _token, uint256 _lpAmount, uint256 _initialPricePerEth)
        public
        onlyTokenOwnerOrMaintenance
        returns (uint256 lpTokenId)
    {
        // Input validations
        if (_lpAmount == 0) revert INVALID_AMOUNT();
        if (_initialPricePerEth > 0.98 ether) revert PRICE_TOO_HIGH();

        // Get chain-specific addresses
        (address weth, INonfungiblePositionManager nonfungiblePositionManager) = getAddresses();

        // Approve position manager to spend tokens
        InstantLiquidityToken(_token).approve(address(nonfungiblePositionManager), _lpAmount);

        // Get mint parameters
        (INonfungiblePositionManager.MintParams memory mintParams, uint160 initialSquareRootPrice) =
        _getMintParams({
            token: _token,
            weth: weth,
            initialPricePerEth: _initialPricePerEth,
            liquidityIn: _lpAmount
        });

        // Sort token addresses
        address token0 = _token < weth ? _token : weth;
        address token1 = _token < weth ? weth : _token;

        // Create pool
        address poolAddress = nonfungiblePositionManager.createAndInitializePoolIfNecessary({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            sqrtPriceX96: initialSquareRootPrice
        });

        // Mint position
        (lpTokenId,,,) = nonfungiblePositionManager.mint({params: mintParams});

        emit LiquidityPoolCreated(_token, _lpAmount, lpTokenId, poolAddress);

        return lpTokenId;
    }

    // /**
    //  * @dev Collects fees from LP positions
    //  * @param recipient Address to receive the fees
    //  * @param tokenIds Array of LP position NFT IDs
    //  */
    // function collectFees(address recipient, uint256[] memory tokenIds)
    //     public
    //     override
    //     onlyMaintenance
    // {
    //     (, INonfungiblePositionManager nonfungiblePositionManager) = getAddresses();

    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         nonfungiblePositionManager.collect(
    //             INonfungiblePositionManager.CollectParams({
    //                 recipient: recipient,
    //                 amount0Max: type(uint128).max,
    //                 amount1Max: type(uint128).max,
    //                 tokenId: tokenIds[i]
    //             })
    //         );

    //         emit FeesCollected(recipient, tokenIds[i]);
    //     }
    // }
}
