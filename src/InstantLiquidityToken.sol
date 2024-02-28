// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {POOL_AMOUNT, OWNER_ALLOCATION} from "./Constants.sol";

contract InstantLiquidityToken is ERC20Upgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner, string memory _name, string memory _symbol) public initializer {
        __ERC20_init(_name, _symbol);

        _mint(msg.sender, POOL_AMOUNT);
        _mint(_owner, OWNER_ALLOCATION);
    }
}
