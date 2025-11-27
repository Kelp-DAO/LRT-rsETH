// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IWstETH
 * @notice Interface for the wstETH token
 */
interface IWstETH {
    /**
     * @notice Exchanges wstETH to stETH
     * @param _wstETHAmount amount of wstETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_wstETHAmount` must be non-zero
     *  - msg.sender must have at least `_wstETHAmount` wstETH.
     * @return Amount of stETH user receives after unwrap
     */
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}
