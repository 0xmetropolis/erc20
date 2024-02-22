// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SolmateERC20} from "../utils/ERC20.sol";

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

interface INonfungiblePositionManager {
    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}



address constant NonFungiblePositionManager = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1; 
address constant WETHToken = 0x4200000000000000000000000000000000000006;


uint160 constant INITIAL_PRICE = 2505288394476896181651817945149;
uint256 constant AMOUNT = 9999999999000000000000000000;
uint8 constant FEE = 100;

address constant TOKEN0 = WETHToken;


contract LiquidityHelperUniV3 {
    SampleToken public token;

    address public owner;
    constructor(address _token){
        token = SampleToken(_token);
        owner = msg.sender;
    }

    int private singleInit = 0;

    function init () public returns (uint256, uint128, uint256, uint256, address, address){
        require(msg.sender == owner, "SLT: only owner");
        require(singleInit == 0, "SLT: can only init once");
        singleInit = 1;

        address TOKEN1 = address(token);

        INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(
            NonFungiblePositionManager
        );

           address pool = INonfungiblePositionManager(
            NonFungiblePositionManager
        )
            .createAndInitializePoolIfNecessary(
                TOKEN0,
                TOKEN1,
                FEE,
                INITIAL_PRICE
            );

        // approves nonfungible position manager
        token.approve(address(nonfungiblePositionManager), AMOUNT + 1000000);


        // mint the position
        MintParams memory mintParams = MintParams({
            token0: TOKEN0,
            token1: TOKEN1,
            fee: FEE,
            tickLower: -138163,
            tickUpper: 69080,
            amount0Desired: 0,
            amount1Desired: AMOUNT,
            amount0Min: 0,
            amount1Min: AMOUNT,
            deadline: type(uint256).max,
            recipient: msg.sender
        });

        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = nonfungiblePositionManager.mint(mintParams);

        return (tokenId, liquidity, amount0, amount1, pool, address(this));
    }
    
}



contract SampleToken is SolmateERC20 {
    address public owner;
    LiquidityHelperUniV3 public liquidityHelperUniV3;

    constructor(string memory _name, string memory _symbol) {
        owner = msg.sender;
        super.initialize(_name, _symbol, 18);

        liquidityHelperUniV3 = new LiquidityHelperUniV3(address(this));

        // mints to the Liquidity Helper
        _mint(address(liquidityHelperUniV3), AMOUNT);
    }

    function initLiquidity() public {
        require(msg.sender == owner, "SLT: only owner");

        liquidityHelperUniV3.init();
    }
}


