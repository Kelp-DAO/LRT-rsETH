// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title KERNEL - Kernel protocol token
contract KERNEL is ERC20, ERC20Permit {
    constructor(address safeAddress) ERC20("KERNEL", "KERNEL") ERC20Permit("KERNEL") {
        _mint(safeAddress, 1_000_000_000 * 10 ** decimals());
    }
}
