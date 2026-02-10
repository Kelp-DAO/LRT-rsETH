// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAToken is IERC20 {
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
