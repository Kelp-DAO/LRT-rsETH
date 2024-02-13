// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IEigenDelayedWithdrawalRouter {
    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) external;
}
