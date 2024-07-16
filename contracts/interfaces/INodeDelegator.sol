// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IStrategy, IERC20 } from "contracts/external/eigenlayer/interfaces/IStrategy.sol";
import { IEigenDelegationManager } from "contracts/external/eigenlayer/interfaces/IEigenDelegationManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event WithdrawalQueued(uint256 nonce, address withdrawer, bytes32[] withdrawalRoots);
    event EthTransferred(address to, uint256 amount);
    event EigenLayerWithdrawalCompleted(address indexed depositor, uint256 nonce, address indexed caller);
    event ETHRewardsReceived(uint256 amount);
    event ETHExtraStakeToReceiveIncremented(uint256 amount);
    event ExtraStakeReceived(uint256 amount);
    event ETHRewardsWithdrawInitiated(uint256 amount);
    event ElSharesDelegated(address indexed elOperator);
    event RestakingActivated();
    event ETHReceived(address indexed sender, uint256 amount);
    event Undelegated();

    // errors
    error TokenTransferFailed();
    error StrategyIsNotSetForAsset();
    error InvalidETHSender();
    error InvalidDepositRoot(bytes32 expectedDepositRoot, bytes32 actualDepositRoot);
    error StrategyMustNotBeBeaconChain();
    error InsufficientStakedButUnverifiedNativeETH();
    error InvalidWithdrawalData();

    // getter
    function stakedButUnverifiedNativeETH() external view returns (uint256);

    // write functions
    function depositAssetIntoStrategy(address asset) external;
    function maxApproveToEigenStrategyManager(address asset) external;
    function initiateUnstaking(
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    )
        external
        returns (bytes32 withdrawalRoot);

    function completeUnstaking(
        IEigenDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex
    )
        external;

    // view functions
    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256);

    function getETHEigenPodBalance() external view returns (uint256);

    function transferBackToLRTDepositPool(address asset, uint256 amount) external;

    function sendETHFromDepositPoolToNDC() external payable;
}
