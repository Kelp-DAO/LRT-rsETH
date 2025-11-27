// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IStrategy, IERC20 } from "contracts/external/eigenlayer/interfaces/IStrategy.sol";
import { IDelegationManagerTypes } from "contracts/external/eigenlayer/interfaces/IDelegationManager.sol";
import { BeaconChainProofs } from "../external/eigenlayer/libraries/BeaconChainProofs.sol";
import { IRewardsCoordinator } from "../external/eigenlayer/interfaces/IRewardsCoordinator.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event ETHDepositFromUnstakingVault(uint256 depositAmount);

    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event WithdrawalQueued(uint256 nonce, address withdrawer, bytes32[] withdrawalRoots);
    event EthTransferred(address to, uint256 amount);
    event AssetTransferred(address asset, address to, uint256 amount);
    event EigenLayerWithdrawalCompleted(address indexed depositor, uint256 nonce, address indexed caller);
    event ExtraStakeReceived(uint256 amount);
    event ElSharesDelegated(address indexed elOperator);
    event ETHReceived(address indexed sender, uint256 amount);
    event Undelegated();

    // errors

    error StrategyIsNotSetForAsset();
    error InvalidETHSender();
    error InvalidDepositRoot(bytes32 expectedDepositRoot, bytes32 actualDepositRoot);
    error InvalidWithdrawalData();
    error PubkeyAlreadyRegistered();
    error ForcedOperatorUndelegation();
    error CallerNotLRTUnstakingVault();
    error CantUndelegate();
    error MaxUncompletedWithdrawalsReached();
    error InsufficientStakedBalance();
    error ZeroLengthArray();
    error ArrayLengthMismatch();
    error InvalidWithdrawalStaker();
    error StrategyAndAssetTokenMismatch();

    // getter
    function stakedButUnverifiedNativeETH() external view returns (uint256);

    // write functions
    function verifyWithdrawalCredentials(
        uint64 beaconTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    )
        external;
    function startCheckpoint(bool revertIfNoBalance) external;

    function depositAssetIntoStrategy(address asset) external;
    function maxApproveToEigenStrategyManager(address asset) external;
    function revokeApprovalToEigenStrategyManager(address asset) external;
    function initiateUnstaking(
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    )
        external
        returns (bytes32 withdrawalRoot);

    function completeUnstaking(
        IDelegationManagerTypes.Withdrawal calldata withdrawal,
        IERC20[] calldata assets
    )
        external;

    // view functions
    function elOperatorDelegatedTo() external view returns (address);

    function getAssetBalance(address asset) external view returns (uint256);

    function getEffectivePodShares() external view returns (uint256);

    function transferBackToLRTDepositPool(address asset, uint256 amount) external;

    function sendETHFromDepositPoolToNDC() external payable;

    function sendETHFromUnstakingVaultToNDC() external payable;

    function processClaim(IRewardsCoordinator.RewardsMerkleClaim calldata claim) external;

    function getAssetUnstaking(address asset) external view returns (uint256 amount);
}
