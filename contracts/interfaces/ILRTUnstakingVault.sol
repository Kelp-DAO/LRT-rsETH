// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IStrategy } from "../external/eigenlayer/interfaces/IStrategy.sol";

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

    // functions

    function getStakedAssetBalances(address user) external view returns (address[] memory, uint256[] memory);

    function balanceOf(address asset) external view returns (uint256);

    function redeem(address asset, uint256 amount) external;

    function getAssetsUnstaking(address asset) external view returns (uint256);

    // receive functions
    function receiveFromLRTDepositPool() external payable;
    function receiveFromNodeDelegator() external payable;

    function reduceSharesUnstaking(address asset, uint256 amount) external;

    function setMaxUncompletedWithdrawalCount(uint256 _maxUncompletedWithdrawalCount) external;
    function increaseUncompletedWithdrawalCount() external;
    function decreaseUncompletedWithdrawalCount() external;

    function uncompletedWithdrawalCount() external view returns (uint256);
    function maxUncompletedWithdrawalCount() external view returns (uint256);
}
