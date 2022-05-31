// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";


contract LivepeerTitanNodeToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Livepeer Titan Node Token", "LTNT") {
        _mint(msg.sender, initialSupply);
    }
}