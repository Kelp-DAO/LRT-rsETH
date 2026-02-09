// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title WadMath Library
/// @notice Library for handling WAD (1e18) math operations
library WadMath {
    using Math for uint256;

    uint256 internal constant WAD = 1e18;

    /// @notice Multiplies two WAD numbers
    /// @param x First WAD number
    /// @param y Second WAD number
    /// @return z Result of multiplication in WAD
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mulDiv(y, WAD);
    }

    /// @notice Divides two WAD numbers
    /// @param x First WAD number
    /// @param y Second WAD number
    /// @return z Result of division in WAD
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x.mulDiv(WAD, y);
    }
}
