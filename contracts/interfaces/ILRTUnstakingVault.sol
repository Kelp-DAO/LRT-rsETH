// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILRTUnstakingVault {
    error CallerNotLRTNodeDelegator();
    error EthTransferFailed();
    error CallerNotLRTWithdrawalManager();
    error WithdrawalAlreadyRegistered();
    error IncorrectStaker();
    error WithdrawalNotPending();
    error MaxUncompletedWithdrawalCountTooHigh();

    event EthReceived(address sender, uint256 amount);
    event EthTransferred(address nodeDelegator, uint256 amount);
    event MaxUncompletedWithdrawalCountSet(uint256 maxUncompletedWithdrawalCount);
    event UncompletedWithdrawalCountSet(uint256 uncompletedWithdrawalCount);
    event QueuedWithdrawalsBufferUpdated(address indexed asset, uint256 buffer);

    // functions

    function getStakedAssetBalances(address user) external view returns (address[] memory, uint256[] memory);

    function balanceOf(address asset) external view returns (uint256);

    function redeem(address asset, uint256 amount) external;

    // receive functions
    function receiveFromLRTDepositPool() external payable;
    function receiveFromNodeDelegator() external payable;

    function setMaxUncompletedWithdrawalCount(uint256 _maxUncompletedWithdrawalCount) external;
    function increaseUncompletedWithdrawalCount() external;
    function decreaseUncompletedWithdrawalCount() external;

    function setQueuedWithdrawalsBuffer(address asset, uint256 buffer) external;

    function uncompletedWithdrawalCount() external view returns (uint256);
    function maxUncompletedWithdrawalCount() external view returns (uint256);
    function queuedWithdrawalsBuffer(address asset) external view returns (uint256);
    function getAssetsAvailableForInstantWithdrawal(address asset) external view returns (uint256);
}
