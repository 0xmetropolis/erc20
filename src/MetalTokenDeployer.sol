// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

/// @notice This is a mock contract of the ERC20 standard for testing purposes only, it SHOULD NOT be used in production.
/// @dev Forked from: https://github.com/transmissions11/solmate/blob/0384dbaaa4fcb5715738a9254a7c0a4cb62cf458/src/tokens/ERC20.sol
contract SolmateERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal INITIAL_CHAIN_ID;

    bytes32 internal INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               INITIALIZE
    //////////////////////////////////////////////////////////////*/

    /// @dev A bool to track whether the contract has been initialized.
    bool private initialized;

    /// @dev To hide constructor warnings across solc versions due to different constructor visibility requirements and
    /// syntaxes, we add an initialization function that can be called only once.
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public {
        require(!initialized, "ALREADY_INITIALIZED");

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = _pureChainId();
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();

        initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(
        address spender,
        uint256 amount
    ) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        balanceOf[msg.sender] = _sub(balanceOf[msg.sender], amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != ~uint256(0))
            allowance[from][msg.sender] = _sub(allowed, amount);

        balanceOf[from] = _sub(balanceOf[from], amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        address recoveredAddress = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256(
                                "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                            ),
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "INVALID_SIGNER"
        );

        allowance[recoveredAddress][spender] = value;

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return
            _pureChainId() == INITIAL_CHAIN_ID
                ? INITIAL_DOMAIN_SEPARATOR
                : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    _pureChainId(),
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply = _add(totalSupply, amount);
        balanceOf[to] = _add(balanceOf[to], amount);

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] = _sub(balanceOf[from], amount);
        totalSupply = _sub(totalSupply, amount);

        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL SAFE MATH LOGIC
    //////////////////////////////////////////////////////////////*/

    function _add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "ERC20: addition overflow");
        return c;
    }

    function _sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(a >= b, "ERC20: subtraction underflow");
        return a - b;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    // We use this complex approach of `_viewChainId` and `_pureChainId` to ensure there are no
    // compiler warnings when accessing chain ID in any solidity version supported by forge-std. We
    // can't simply access the chain ID in a normal view or pure function because the solc View Pure
    // Checker changed `chainid` from pure to view in 0.8.0.
    function _viewChainId() private view returns (uint256 chainId) {
        // Assembly required since `block.chainid` was introduced in 0.8.0.
        assembly {
            chainId := chainid()
        }

        address(this); // Silence warnings in older Solc versions.
    }

    function _pureChainId() private pure returns (uint256 chainId) {
        function() internal view returns (uint256) fnIn = _viewChainId;
        function() internal pure returns (uint256) pureChainId;
        assembly {
            pureChainId := fnIn
        }
        chainId = pureChainId();
    }
}

contract MetalToken is SolmateERC20 {
    address public owner;

    constructor(address _owner, string memory _name, string memory _symbol) {
        owner = _owner;
        super.initialize(_name, _symbol, 18);
        // mints to the TokenDeployer
        _mint(msg.sender, 10000000000000000000000000000);
    }

    function mint(address to, uint256 amount) public {
        require(msg.sender == owner, "MetalToken: only owner");
        _mint(to, amount);
    }
}

uint256 constant AMOUNT = 9999999999000000000000000000;

contract TokenDeployer {
    uint160 public constant INITIAL_PRICE = 2505288394476896181651817945149;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    // non fungible position manager:
    /**
    sepolia 0x1238536071E1c677A632429e3655c799b22cDA52
    base 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
    everywhere else 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
     */
    mapping(uint256 => address) internal WETHTOKENS;

    constructor(address _nonfungiblePositionManager) {
        nonfungiblePositionManager = INonfungiblePositionManager(
            _nonfungiblePositionManager
        );
        WETHTOKENS[8453] = 0x4200000000000000000000000000000000000006;
    }

    function deploy(
        string memory _name,
        string memory _symbol
    ) public returns (uint256, uint128, uint256, uint256, address, address) {
        MetalToken token = new MetalToken(msg.sender, _name, _symbol);
        token.approve(address(nonfungiblePositionManager), AMOUNT);

        // get the weth address for the chain id
        address weth = WETHTOKENS[block.chainid];

        (address token0, address token1) = (weth, address(token));
        
        // call createAndInitializePoolIfNecessary
        address pool = nonfungiblePositionManager
            .createAndInitializePoolIfNecessary(
                token0,
                token1,
                100,
                INITIAL_PRICE
            );

        // mint the position
        MintParams memory mintParams = MintParams({
            token0: token0,
            token1: token1,
            fee: 100,
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

        return (tokenId, liquidity, amount0, amount1, pool, address(token));
    }
}
