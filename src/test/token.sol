// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Test Token - For development purposes only
/// @dev Test Token with large supply

contract Token is ERC20 {
    uint256 constant _initial_supply = 10 ** 50 * (10 ** 18);

    uint256 public value;

    constructor() ERC20("DAI", "DAI") {
        _mint(msg.sender, _initial_supply);
    }
}
