// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @title UtilLib - Utility library
/// @notice Utility functions
library UtilLib {
    error ZeroAddressNotAllowed();

    /// @dev zero address check modifier
    /// @param address_ address to check
    function checkNonZeroAddress(address address_) internal pure {
        if (address_ == address(0)) revert ZeroAddressNotAllowed();
    }

    function getMin(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a < b) return a;
        return b;
    }

    function getMax(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) return a;
        return b;
    }
}
