// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./IStrategy.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event ETHRewardsClaimed(uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);

    // errors
    error TokenTransferFailed();
    error StrategyIsNotSetForAsset();
    error InvalidETHSender();
    error InvalidRewardAmount();
    error InvalidDepositRoot(bytes32 expectedDepositRoot, bytes32 actualDepositRoot);

    // getter

    function stakedButUnverifiedNativeETH() external view returns (uint256);

    // methods
    function depositAssetIntoStrategy(address asset) external;

    function maxApproveToEigenStrategyManager(address asset) external;

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256);
    function getETHEigenPodBalance() external view returns (uint256);
    function transferBackToLRTDepositPool(address asset, uint256 amount) external;
    function sendETHFromDepositPoolToNDC() external payable;
}
