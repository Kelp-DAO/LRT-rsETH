// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IFeeReceiver {
    // Errors
    error InvalidEmptyValue();

    // events
    event MevRewardsAddedToTVL(uint256 amount);
}
