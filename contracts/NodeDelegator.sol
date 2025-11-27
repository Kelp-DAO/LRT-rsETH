// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// openzeppelin or other standard contracts
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// external libraries, interfaces, contracts
import { IEigenPod } from "./external/eigenlayer/interfaces/IEigenPod.sol";
import { IStrategyManager } from "./external/eigenlayer/interfaces/IStrategyManager.sol";
import { IEigenPodManager, IETHPOSDeposit } from "./external/eigenlayer/interfaces/IEigenPodManager.sol";

// protocol libraries, interfaces, contracts
import { UtilLib } from "./utils/UtilLib.sol";

import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker } from "./utils/LRTConfigRoleChecker.sol";

import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { IPubkeyRegistry } from "./interfaces/IPubkeyRegistry.sol";
import {
    INodeDelegator,
    BeaconChainProofs,
    IERC20,
    IStrategy,
    IRewardsCoordinator,
    IDelegationManagerTypes
} from "./interfaces/INodeDelegator.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { NodeDelegatorHelper } from "./NodeDelegatorHelper.sol";
import { IDelegationManager } from "contracts/external/eigenlayer/interfaces/IDelegationManager.sol";

/// @title NodeDelegator Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegator is INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using LRTConstants for ILRTConfig;

    /// @dev The EigenPod is created and owned by this contract
    IEigenPod public eigenPod;

    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    uint256 public stakedButUnverifiedNativeETH;

    /// @dev address of eigenlayer operator to which all restaked funds are delegated to
    /// @dev it is only possible to delegate fully to only one operator per NDC contract
    address private __elOperatorDelegatedTo;

    /// @dev amount of eth expected to receive from extra eth staked for validators
    uint256 private __legacyExtraStakeToReceive;

    uint256 private lastNonce;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();

        lrtConfig = ILRTConfig(lrtConfigAddr);

        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    function initialize2() external reinitializer(2) {
        lastNonce = _getNonce();
    }

    /// @dev due to a bit heavy logic, eth transfer using `transfer()` and `send()` will fail
    /// @dev hence please use `call()` to send eth to this contract
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                            EigenLayer Interactions
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits an asset lying in this NDC into its strategy
    /// @dev only supported assets can be deposited and only called by the LRT operator
    /// @param asset the asset to deposit
    function depositAssetIntoStrategy(address asset)
        external
        override
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
        onlyLRTOperator
    {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            revert StrategyIsNotSetForAsset();
        }

        IERC20 token = IERC20(asset);

        uint256 balance = token.balanceOf(address(this));

        IStrategyManager(lrtConfig.strategyManager()).depositIntoStrategy(IStrategy(strategy), token, balance);

        emit AssetDepositIntoStrategy(asset, strategy, balance);
    }

    /// @notice Delegates shares (accrued by restaking LSTs/native eth) to an EigenLayer operator
    /// @param elOperator The address of the operator to delegate to
    /// @param approverSignatureAndExpiry Verifies the operator approves of this delegation
    /// @param approverSalt A unique single use value tied to an individual signature.
    /// @dev delegationManager.delegateTo will check if the operator is valid, if ndc is already delegated to
    function delegateTo(
        address elOperator,
        IDelegationManager.SignatureWithExpiry calldata approverSignatureAndExpiry,
        bytes32 approverSalt
    )
        external
        onlyLRTManager
    {
        UtilLib.checkNonZeroAddress(elOperator);
        _getDelegationManager().delegateTo(elOperator, approverSignatureAndExpiry, approverSalt);
        emit ElSharesDelegated(elOperator);
    }

    /**
     * @notice Creates an EigenPod for this NodeDelegator.
     * @dev Function will revert if the `NodeDelegator` already has an EigenPod.
     * @dev Sets EigenPod address
     */
    function createEigenPod() external onlyLRTManager {
        eigenPod = IEigenPod(_getEigenPodManager().createPod());
        emit EigenPodCreated(address(eigenPod), address(this));
    }

    /// @notice Stake ETH from NDC into EigenLayer. it calls the stake function in the EigenPodManager
    /// which in turn calls the stake function in the EigenPod
    /// @param pubkey The pubkey of the validator
    /// @param signature The signature of the validator
    /// @param depositDataRoot The deposit data root of the validator
    /// @dev Only LRT Operator should call this function
    /// @dev Exactly 32 ether is allowed, hence it is hardcoded
    /// @dev offchain checks withdraw credentials authenticity
    function stake32Eth(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot
    )
        public
        whenNotPaused
        onlyLRTOperator
    {
        IPubkeyRegistry pubkeyRegistry = IPubkeyRegistry(lrtConfig.pubkeyRegistry());
        if (pubkeyRegistry.hasPubkey(pubkey)) {
            revert PubkeyAlreadyRegistered();
        }
        pubkeyRegistry.addPubkey(pubkey);

        // tracks staked but unverified native ETH
        stakedButUnverifiedNativeETH += 32 ether;

        _getEigenPodManager().stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        if (address(eigenPod) == address(0)) {
            eigenPod = _getEigenPodManager().ownerToPod(address(this));
            emit EigenPodCreated(address(eigenPod), address(this));
        }
        emit ETHStaked(pubkey, 32 ether);
    }

    /// @notice Stake ETH from NDC into EigenLayer
    /// @param pubkey The pubkey of the validator
    /// @param signature The signature of the validator
    /// @param depositDataRoot The deposit data root of the validator
    /// @param expectedDepositRoot The expected deposit data root, which is computed offchain
    /// @dev Only LRT Operator should call this function
    /// @dev Exactly 32 ether is allowed, hence it is hardcoded
    /// @dev offchain checks withdraw credentials authenticity
    /// @dev compares expected deposit root with actual deposit root
    function stake32EthValidated(
        bytes calldata pubkey,
        bytes calldata signature,
        bytes32 depositDataRoot,
        bytes32 expectedDepositRoot
    )
        external
    {
        IETHPOSDeposit depositContract = _getEigenPodManager().ethPOS();
        bytes32 actualDepositRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualDepositRoot) {
            revert InvalidDepositRoot(expectedDepositRoot, actualDepositRoot);
        }
        stake32Eth(pubkey, signature, depositDataRoot);
    }

    function processClaim(IRewardsCoordinator.RewardsMerkleClaim calldata claim)
        external
        onlyLRTOperator
        whenNotPaused
        nonReentrant
    {
        IRewardsCoordinator(lrtConfig.rewardsCoordinator()).processClaim(claim, lrtConfig.eigenLayerRewardReceiver());
    }

    /**
     * @dev Verify one or more validators have their withdrawal credentials pointed at this EigenPod, and award
     * shares based on their effective balance. Proven validators are marked `ACTIVE` within the EigenPod, and
     * future checkpoint proofs will need to include them.
     * @dev Withdrawal credential proofs MUST NOT be older than `currentCheckpointTimestamp`.
     * @dev Validators proven via this method MUST NOT have an exit epoch set already.
     * @param beaconTimestamp the beacon chain timestamp sent to the 4788 oracle contract. Corresponds
     * to the parent beacon block root against which the proof is verified.
     * @param stateRootProof proves a beacon state root against a beacon block root
     * @param validatorIndices a list of validator indices being proven
     * @param validatorFieldsProofs proofs of each validator's `validatorFields` against the beacon state root
     * @param validatorFields the fields of the beacon chain "Validator" container. See consensus specs for
     * details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 beaconTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    )
        external
        onlyLRTOperator
    {
        if (stakedButUnverifiedNativeETH < validatorFields.length * (32 ether)) {
            revert InsufficientStakedBalance();
        }

        // reduce the eth amount that is verified
        stakedButUnverifiedNativeETH -= (validatorFields.length * (32 ether));

        eigenPod.verifyWithdrawalCredentials(
            beaconTimestamp, stateRootProof, validatorIndices, validatorFieldsProofs, validatorFields
        );
    }

    /**
     * @dev Create a checkpoint used to prove this pod's active validator set. Checkpoints are completed
     * by submitting one checkpoint proof per ACTIVE validator. During the checkpoint process, the total
     * change in ACTIVE validator balance is tracked, and any validators with 0 balance are marked `WITHDRAWN`.
     * @dev Once finalized, the pod owner is awarded shares corresponding to:
     * - the total change in their ACTIVE validator balances
     * - any ETH in the pod not already awarded shares
     * @dev A checkpoint cannot be created if the pod already has an outstanding checkpoint. If
     * this is the case, the pod owner MUST complete the existing checkpoint before starting a new one.
     * @param revertIfNoBalance Forces a revert if the pod ETH balance is 0. This allows the pod owner
     * to prevent accidentally starting a checkpoint that will not increase their shares
     */
    function startCheckpoint(bool revertIfNoBalance) external onlyLRTOperator {
        eigenPod.startCheckpoint(revertIfNoBalance);
    }

    /// @notice undelegates from operator and removes all currently active shares
    function undelegate() external whenNotPaused onlyLRTManager {
        if (elOperatorDelegatedTo() == address(0)) {
            revert CantUndelegate();
        }

        bytes32[] memory withdrawalRoots = _getDelegationManager().undelegate(address(this));

        if (
            _getUnstakingVault().uncompletedWithdrawalCount() + withdrawalRoots.length
                > _getUnstakingVault().maxUncompletedWithdrawalCount()
        ) {
            revert MaxUncompletedWithdrawalsReached();
        }

        for (uint256 i; i < withdrawalRoots.length; i++) {
            _getUnstakingVault().increaseUncompletedWithdrawalCount();

            // NOTE: For legacy event emission we emit single withdrawal roots
            bytes32[] memory singleWithdrawal = new bytes32[](1);
            singleWithdrawal[0] = withdrawalRoots[i];
            emit WithdrawalQueued(_getNonce() - withdrawalRoots.length + i, address(this), singleWithdrawal);
        }

        emit Undelegated();
    }

    /// @notice Queues a withdrawal from the strategies
    /// @param strategies Array of strategies withdrawals
    /// @param shares Array of shares to withdraw
    function initiateUnstaking(
        IStrategy[] calldata strategies,
        uint256[] calldata shares
    )
        external
        override
        nonReentrant
        whenNotPaused
        onlyLRTOperator
        returns (bytes32 withdrawalRoot)
    {
        if (_getUnstakingVault().uncompletedWithdrawalCount() >= _getUnstakingVault().maxUncompletedWithdrawalCount()) {
            revert MaxUncompletedWithdrawalsReached();
        }
        if (strategies.length == 0) {
            revert ZeroLengthArray();
        }

        if (strategies.length != shares.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < strategies.length; i++) {
            if (!NodeDelegatorHelper.isSupportedStrategy(lrtConfig, strategies[i])) {
                revert StrategyIsNotSetForAsset();
            }
        }

        IDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = IDelegationManagerTypes.QueuedWithdrawalParams({
            strategies: strategies,
            depositShares: shares,
            withdrawer: address(this)
        });

        bytes32[] memory withdrawalRoots = _getDelegationManager().queueWithdrawals(queuedWithdrawalParams);
        withdrawalRoot = withdrawalRoots[0];
        emit WithdrawalQueued(_getNonce() - 1, address(this), withdrawalRoots);
    }

    /// @notice Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    function completeUnstaking(IDelegationManager.Withdrawal calldata withdrawal, IERC20[] calldata assets) external {
        completeUnstaking(withdrawal, assets, true);
    }

    /// @notice Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    /// @param receiveAsTokens Whether or not to complete each withdrawal as tokens. See `completeQueuedWithdrawal` for
    /// the usage of a single boolean.
    function completeUnstaking(
        IDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        bool receiveAsTokens
    )
        public
        nonReentrant
        whenNotPaused
        onlyLRTOperator
    {
        if (withdrawal.staker != address(this)) {
            revert InvalidWithdrawalStaker();
        }

        uint256 assetCount = assets.length;
        if (assetCount == 0 || assetCount != withdrawal.scaledShares.length) {
            // asset length and strategies length is checked by eigenlayer contracts in `completeQueuedWithdrawal`
            revert InvalidWithdrawalData();
        }

        for (uint256 i; i < assetCount; i++) {
            if (address(assets[i]) != address(withdrawal.strategies[i].underlyingToken())) {
                revert StrategyAndAssetTokenMismatch();
            }
        }

        uint256[] memory balancesBefore = getBalances(assets);

        // Finalize withdrawal with Eigenlayer Delegation Manager
        _getDelegationManager().completeQueuedWithdrawal(withdrawal, assets, receiveAsTokens);
        // NOTE: For legacy el withdrawal support, this can be removed after all pre slashing withdrawals are processed
        if (withdrawal.nonce < lastNonce) {
            for (uint256 i; i < assetCount; i++) {
                if (lrtConfig.beaconChainETHStrategy() != address(withdrawal.strategies[i])) {
                    _getUnstakingVault().reduceSharesUnstaking(
                        address(withdrawal.strategies[i].underlyingToken()), withdrawal.scaledShares[i]
                    );
                } else {
                    _getUnstakingVault().reduceSharesUnstaking(LRTConstants.ETH_TOKEN, withdrawal.scaledShares[i]);
                }
            }
        } else {
            _getUnstakingVault().decreaseUncompletedWithdrawalCount();
        }
        if (receiveAsTokens) {
            for (uint256 i; i < assetCount; i++) {
                if (address(assets[i]) == LRTConstants.ETH_TOKEN) {
                    emit EthTransferred(address(_getUnstakingVault()), address(this).balance - balancesBefore[i]);
                    _getUnstakingVault().receiveFromNodeDelegator{ value: address(this).balance - balancesBefore[i] }();
                } else {
                    assets[i].safeTransfer(
                        address(_getUnstakingVault()), assets[i].balanceOf(address(this)) - balancesBefore[i]
                    );
                }
            }
        }

        emit EigenLayerWithdrawalCompleted(withdrawal.staker, withdrawal.nonce, msg.sender);
    }

    /// @notice Returns the amount of a specific asset currently being unstaked
    /// @param asset The address of the asset to check
    /// @return amount The total amount of the asset being unstaked
    function getAssetUnstaking(address asset) public view returns (uint256 amount) {
        (IDelegationManager.Withdrawal[] memory queuedWithdrawals, uint256[][] memory withdrawalShares) =
            _getDelegationManager().getQueuedWithdrawals(address(this));

        for (uint256 withdrawalIndex = 0; withdrawalIndex < queuedWithdrawals.length; withdrawalIndex++) {
            IDelegationManager.Withdrawal memory withdrawal = queuedWithdrawals[withdrawalIndex];

            // Note: This can be removed after lastNonce is initilized, onlySupportedAsset should check this
            if (withdrawal.nonce < lastNonce) {
                continue;
            }

            for (uint256 strategyIndex = 0; strategyIndex < withdrawal.strategies.length; strategyIndex++) {
                IStrategy strategy = withdrawal.strategies[strategyIndex];

                address strategyAsset = address(strategy) == address(lrtConfig.beaconChainETHStrategy())
                    ? LRTConstants.ETH_TOKEN
                    : address(strategy.underlyingToken());

                if (strategyAsset != asset) continue;

                uint256 sharesToUnstake = withdrawalShares[withdrawalIndex][strategyIndex];
                amount += strategyAsset == LRTConstants.ETH_TOKEN
                    ? sharesToUnstake
                    : strategy.sharesToUnderlyingView(sharesToUnstake);
            }
        }
    }

    function getBalances(IERC20[] memory assets) internal view returns (uint256[] memory balances) {
        balances = new uint256[](assets.length);
        for (uint256 i; i < assets.length; i++) {
            if (address(assets[i]) == LRTConstants.ETH_TOKEN) {
                balances[i] = address(this).balance;
            } else {
                balances[i] = assets[i].balanceOf(address(this));
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Operational Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Sends ETH from the LRT deposit pool to this contract
    function sendETHFromDepositPoolToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        if (msg.sender != lrtConfig.depositPool()) {
            revert InvalidETHSender();
        }

        emit ETHDepositFromDepositPool(msg.value);
    }

    /// @notice Sends ETH from the LRT Unstaking Vault to this contract
    function sendETHFromUnstakingVaultToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        if (msg.sender != lrtConfig.unstakingVault()) {
            revert InvalidETHSender();
        }
        emit ETHDepositFromUnstakingVault(msg.value);
    }

    /// @notice Transfers an asset back to the LRT deposit pool
    /// @dev only supported assets can be transferred and only called by the LRT manager
    /// @param asset the asset to transfer
    /// @param amount the amount to transfer
    function transferBackToLRTDepositPool(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
        onlyLRTOperator
    {
        address lrtDepositPool = lrtConfig.depositPool();

        if (asset == LRTConstants.ETH_TOKEN) {
            ILRTDepositPool(lrtDepositPool).receiveFromNodeDelegator{ value: amount }();

            emit EthTransferred(lrtDepositPool, amount);
        } else {
            IERC20(asset).safeTransfer(lrtDepositPool, amount);

            emit AssetTransferred(asset, lrtDepositPool, amount);
        }
    }

    /// @notice Transfers ETH back to the LRT Unstaking Vault
    /// @dev only supported assets can be transferred and only called by the LRT manager
    /// @param amount the amount to transfer
    function transferETHToLRTUnstakingVault(uint256 amount) external nonReentrant whenNotPaused onlyLRTOperator {
        _getUnstakingVault().receiveFromNodeDelegator{ value: amount }();
        emit EthTransferred(address(_getUnstakingVault()), amount);
    }

    /*//////////////////////////////////////////////////////////////
                    Other Write Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Approves the maximum amount of an asset to the eigen strategy manager
    /// @dev only supported assets can be deposited and only called by the LRT manager
    /// @param asset the asset to deposit
    function maxApproveToEigenStrategyManager(address asset)
        external
        override
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        IERC20(asset).approve(lrtConfig.strategyManager(), type(uint256).max);
    }

    /// @notice Revokes the approval of an asset to the eigen strategy manager
    /// @dev can only b called by the LRT manager
    /// @param asset the asset to revoke approval for
    function revokeApprovalToEigenStrategyManager(address asset) external override onlyLRTManager {
        IERC20(asset).approve(lrtConfig.strategyManager(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    Setters / Update Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the balance of an asset that the node delegator has deposited into the strategy
    /// @param asset the asset to get the balance of
    /// @return stakedBalance the balance of the asset
    function getAssetBalance(address asset) external view override returns (uint256) {
        return NodeDelegatorHelper.getAssetBalance(lrtConfig, asset);
    }

    /// @dev Returns the amount of eth staked in eigenlayer through this ndc
    function getEffectivePodShares() external view override returns (uint256 ethStaked) {
        uint256 withdrawableShare =
            NodeDelegatorHelper.getWithdrawableShare(lrtConfig, IStrategy(lrtConfig.beaconChainETHStrategy()));

        // staker balances can no longer be negative
        return stakedButUnverifiedNativeETH + withdrawableShare;
    }

    function elOperatorDelegatedTo() public view override returns (address) {
        return _getDelegationManager().delegatedTo(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    function _getUnstakingVault() internal view returns (ILRTUnstakingVault) {
        return ILRTUnstakingVault(lrtConfig.unstakingVault());
    }

    function _getDelegationManager() internal view returns (IDelegationManager) {
        return IDelegationManager(lrtConfig.delegationManager());
    }

    function _getEigenPodManager() internal view returns (IEigenPodManager) {
        return IEigenPodManager(lrtConfig.eigenPodManager());
    }

    function _getNonce() internal view returns (uint256) {
        return _getDelegationManager().cumulativeWithdrawalsQueued(address(this));
    }
}
