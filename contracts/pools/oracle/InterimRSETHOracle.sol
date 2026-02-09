// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/// @title InterimRSETHOracle Contract
/// @notice contract where the owner sets the rsETH/ETH rate manually
/// @dev This contract is used as an interim solution until a more robust oracle is implemented
contract InterimRSETHOracle is AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice The current rsETH/ETH rate
    uint256 public rate;

    /// @dev Error thrown when the rate is invalid (less than 1e18)
    error InvalidRate();

    /// @dev Event emitted when the rate is updated
    /// @param newRate The new rsETH/ETH rate
    event RateUpdated(uint256 indexed newRate);

    /// @dev Constructor to set the initial rate and admin
    /// @param admin The address of the admin
    /// @param initRate The initial rsETH/ETH rate
    constructor(address admin, uint256 initRate) {
        UtilLib.checkNonZeroAddress(admin);
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MANAGER_ROLE, admin);
        _setRate(initRate);
    }

    /// @notice Set the rsETH/ETH rate
    /// @param newRate The new rate to set
    function setRate(uint256 newRate) external onlyRole(MANAGER_ROLE) {
        _setRate(newRate);
    }

    /// @dev Internal function to set the rsETH/ETH rate
    function _setRate(uint256 newRate) internal {
        if (newRate < 1e18) revert InvalidRate();
        rate = newRate;
        emit RateUpdated(newRate);
    }

    /// @notice Get the current rsETH/ETH rate
    /// @return The current rate
    function getRate() external view returns (uint256) {
        return rate;
    }
}
