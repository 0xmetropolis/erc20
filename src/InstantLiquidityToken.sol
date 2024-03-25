// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract InstantLiquidityToken is ERC20Upgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _mintTo,
        uint256 _totalSupply,
        string memory _name,
        string memory _symbol
    ) public initializer {
        __ERC20_init(_name, _symbol);
        _mint(_mintTo, _totalSupply);
    }
}
