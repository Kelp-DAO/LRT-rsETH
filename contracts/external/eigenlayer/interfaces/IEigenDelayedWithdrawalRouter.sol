// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IEigenDelayedWithdrawalRouter {
    // struct used to pack data into a single storage slot
    struct DelayedWithdrawal {
        uint224 amount;
        uint32 blockCreated;
    }

    // struct used to store a single users delayedWithdrawal data
    struct UserDelayedWithdrawals {
        uint256 delayedWithdrawalsCompleted;
        DelayedWithdrawal[] delayedWithdrawals;
    }

    function getUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] memory);

    function claimDelayedWithdrawals(address recipient, uint256 maxNumberOfDelayedWithdrawalsToClaim) external;

    function userWithdrawals(address user) external view returns (UserDelayedWithdrawals memory);

    function userWithdrawalsLength(address user) external view returns (uint256);
}
