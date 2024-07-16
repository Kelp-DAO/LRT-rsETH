// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title KELP - KelpDao's protocol token
contract KELP is ERC20, ERC20Permit {
    constructor(address safeAddress) ERC20("KELP", "KELP") ERC20Permit("KELP") {
        _mint(safeAddress, 1_000_000_000 * 10 ** decimals());
    }
}
