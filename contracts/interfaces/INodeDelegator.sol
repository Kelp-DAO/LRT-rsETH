// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IStrategy, IERC20 } from "contracts/external/eigenlayer/interfaces/IStrategy.sol";
import { IDelegationManager } from "contracts/external/eigenlayer/interfaces/IDelegationManager.sol";
import { BeaconChainProofs } from "../external/eigenlayer/libraries/BeaconChainProofs.sol";

interface INodeDelegator {
    // event
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);
    event ETHDepositFromUnstakingVault(uint256 depositAmount);

    event EigenPodCreated(address indexed eigenPod, address indexed podOwner);
    event ETHStaked(bytes valPubKey, uint256 amount);
    event WithdrawalQueued(uint256 nonce, address withdrawer, bytes32[] withdrawalRoots);
    event EthTransferred(address to, uint256 amount);
    event EigenLayerWithdrawalCompleted(address indexed depositor, uint256 nonce, address indexed caller);
    event ETHExtraStakeToReceiveIncremented(uint256 amount);
    event ExtraStakeReceived(uint256 amount);
    event ElSharesDelegated(address indexed elOperator);
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
    error PubkeyAlreadyRegistered();
    error ForcedOperatorUndelegation();
    error CallerNotLRTUnstakingVault();

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
    function initiateUnstaking(
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    )
        external
        returns (bytes32 withdrawalRoot);

    function completeUnstaking(
        IDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex
    )
        external;

    // view functions
    function elOperatorDelegatedTo() external view returns (address);

    function hasAllWithdrawalsAccounted() external view returns (bool);

    function getAssetBalances() external view returns (address[] memory, uint256[] memory);

    function getAssetBalance(address asset) external view returns (uint256);

    function getEffectivePodShares() external view returns (int256);

    function transferBackToLRTDepositPool(address asset, uint256 amount) external;

    function increaseLastNonce() external;

    function sendETHFromDepositPoolToNDC() external payable;

    function sendETHFromUnstakingVaultToNDC() external payable;
}
