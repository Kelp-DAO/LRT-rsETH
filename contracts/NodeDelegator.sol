// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

// openzeppelin or other standard contracts
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// external libraries, interfaces, contracts
import { IEigenPod } from "./external/eigenlayer/interfaces/IEigenPod.sol";
import { IEigenStrategyManager } from "./external/eigenlayer/interfaces/IEigenStrategyManager.sol";
import { IEigenPodManager, IETHPOSDeposit } from "./external/eigenlayer/interfaces/IEigenPodManager.sol";
import { IDelegationManager } from "./external/eigenlayer/interfaces/IDelegationManager.sol";

// protocol libraries, interfaces, contracts
import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker } from "./utils/LRTConfigRoleChecker.sol";

import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { IPubkeyRegistry } from "./interfaces/IPubkeyRegistry.sol";
import { INodeDelegator, BeaconChainProofs, IERC20, IStrategy } from "./interfaces/INodeDelegator.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";

/// @title NodeDelegator Contract
/// @notice The contract that handles the depositing of assets into strategies
contract NodeDelegator is INodeDelegator, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev The EigenPod is created and owned by this contract
    IEigenPod public eigenPod;

    /// @dev Tracks the balance staked to validators and has yet to have the credentials verified with EigenLayer.
    /// call verifyWithdrawalCredentialsAndBalance in EL to verify the validator credentials on EigenLayer
    uint256 public stakedButUnverifiedNativeETH;

    /// @dev address of eigenlayer operator to which all restaked funds are delegated to
    /// @dev it is only possible to delegate fully to only one operator per NDC contract
    address private __elOperatorDelegatedTo;

    /// @dev amount of eth expected to receive from extra eth staked for validators
    uint256 private __legacyExtraStakeToReceive;

    uint256 private lastNonce;

    modifier onlyWhenWithdrawalsAccounted() {
        if (!hasAllWithdrawalsAccounted()) {
            revert ForcedOperatorUndelegation();
        }
        _;
    }

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
        lastNonce = getNonce();
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
    /// @dev only supported assets can be deposited and only called by the LRT manager
    /// @param asset the asset to deposit
    function depositAssetIntoStrategy(address asset)
        external
        override
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            revert StrategyIsNotSetForAsset();
        }

        IERC20 token = IERC20(asset);
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        uint256 balance = token.balanceOf(address(this));

        IEigenStrategyManager(eigenlayerStrategyManagerAddress).depositIntoStrategy(IStrategy(strategy), token, balance);

        emit AssetDepositIntoStrategy(asset, strategy, balance);
    }

    /// @notice Delegates shares (accrued by restaking LSTs/native eth) to an EigenLayer operator
    /// @param elOperator The address of the operator to delegate to
    /// @param approverSignatureAndExpiry Verifies the operator approves of this delegation
    /// @param approverSalt A unique single use value tied to an individual signature.
    /// @dev delegationManager.delegateTo will check if the operator is valid, if ndc is already delegated to
    function delegateTo(
        address elOperator,
        IDelegationManager.SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    )
        external
        onlyLRTManager
    {
        UtilLib.checkNonZeroAddress(elOperator);
        IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER)).delegateTo(
            elOperator, approverSignatureAndExpiry, approverSalt
        );
        emit ElSharesDelegated(elOperator);
    }

    /**
     * @notice Creates an EigenPod for this NodeDelegator.
     * @dev Function will revert if the `NodeDelegator` already has an EigenPod.
     * @dev Sets EigenPod address
     */
    function createEigenPod() external onlyLRTManager {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));

        eigenPod = IEigenPod(eigenPodManager.createPod());

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
        IPubkeyRegistry pubkeyRegistry = IPubkeyRegistry(lrtConfig.getContract(LRTConstants.PUBKEY_REGISTRY));
        if (pubkeyRegistry.hasPubkey(pubkey)) {
            revert PubkeyAlreadyRegistered();
        }
        pubkeyRegistry.addPubkey(pubkey);

        // tracks staked but unverified native ETH
        stakedButUnverifiedNativeETH += 32 ether;

        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        if (address(eigenPod) == address(0)) {
            eigenPod = eigenPodManager.ownerToPod(address(this));
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
        whenNotPaused
        onlyLRTOperator
    {
        IETHPOSDeposit depositContract =
            IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER)).ethPOS();
        bytes32 actualDepositRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualDepositRoot) {
            revert InvalidDepositRoot(expectedDepositRoot, actualDepositRoot);
        }
        stake32Eth(pubkey, signature, depositDataRoot);
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
        IDelegationManager elDelegationManager =
            IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
        ILRTUnstakingVault lrtUnstakingVault =
            ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));
        address beaconChainETHStrategy = lrtConfig.getContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY);

        // Gather strategies and shares which will be removed from staker/operator during undelegation
        (IStrategy[] memory strategies, uint256[] memory shares) =
            elDelegationManager.getDelegatableShares(address(this));

        // update shares unstaking in LRT unstaking vault
        for (uint256 i = 0; i < strategies.length;) {
            if (beaconChainETHStrategy == address(strategies[i])) {
                lrtUnstakingVault.addSharesUnstaking(LRTConstants.ETH_TOKEN, shares[i]);
            } else {
                address token = address(strategies[i].underlyingToken());
                lrtUnstakingVault.addSharesUnstaking(token, shares[i]);
            }
            unchecked {
                ++i;
            }
        }

        uint256 nonce = getNonce();
        bytes32[] memory withdrawalRoots = elDelegationManager.undelegate(address(this));
        lastNonce = lastNonce + getNonce() - nonce;
        for (uint256 i = 0; i < withdrawalRoots.length; i++) {
            lrtUnstakingVault.trackWithdrawal(withdrawalRoots[i]);
        }
        emit WithdrawalQueued(nonce, address(this), withdrawalRoots);
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
        IDelegationManager.QueuedWithdrawalParams memory queuedWithdrawalParam = IDelegationManager
            .QueuedWithdrawalParams({ strategies: strategies, shares: shares, withdrawer: address(this) });

        address beaconChainETHStrategy = lrtConfig.getContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY);

        ILRTUnstakingVault lrtUnstakingVault =
            ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));
        for (uint256 i = 0; i < queuedWithdrawalParam.strategies.length;) {
            if (beaconChainETHStrategy == address(queuedWithdrawalParam.strategies[i])) {
                lrtUnstakingVault.addSharesUnstaking(LRTConstants.ETH_TOKEN, queuedWithdrawalParam.shares[i]);
            } else {
                address token = address(queuedWithdrawalParam.strategies[i].underlyingToken());
                address strategy = lrtConfig.assetStrategy(token);

                if (strategy != address(queuedWithdrawalParam.strategies[i])) {
                    revert StrategyIsNotSetForAsset();
                }
                lrtUnstakingVault.addSharesUnstaking(token, queuedWithdrawalParam.shares[i]);
            }

            unchecked {
                ++i;
            }
        }
        IDelegationManager elDelegationManager =
            IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));

        IDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = queuedWithdrawalParam;
        uint256 nonce = getNonce();
        bytes32[] memory withdrawalRoots = elDelegationManager.queueWithdrawals(queuedWithdrawalParams);
        lastNonce = lastNonce + 1;
        withdrawalRoot = withdrawalRoots[0];
        lrtUnstakingVault.trackWithdrawal(withdrawalRoot);
        emit WithdrawalQueued(nonce, address(this), withdrawalRoots);
    }

    /// @notice Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    /// @param middlewareTimesIndex Index in the middleware times array for withdrawal eligibility check.
    function completeUnstaking(
        IDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex
    )
        external
    {
        completeUnstaking(withdrawal, assets, middlewareTimesIndex, true);
    }

    /// @notice Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    /// @param middlewareTimesIndex Index in the middleware times array for withdrawal eligibility check.
    /// @param receiveAsTokens Whether or not to complete each withdrawal as tokens. See `completeQueuedWithdrawal` for
    /// the usage of a single boolean.
    function completeUnstaking(
        IDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    )
        public
        nonReentrant
        whenNotPaused
        onlyLRTOperator
        onlyWhenWithdrawalsAccounted
    {
        uint256 assetCount = assets.length;
        if (assetCount == 0 || assetCount != withdrawal.shares.length) {
            // asset length and strategies length is checked by eigenlayer contracts in `completeQueuedWithdrawal`
            revert InvalidWithdrawalData();
        }

        address elDelegationManagerAddr = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        address beaconChainETHStrategy = lrtConfig.getContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY);
        address lrtUnstakingVaultAddr = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);

        ILRTUnstakingVault lrtUnstakingVault = ILRTUnstakingVault(lrtUnstakingVaultAddr);

        uint256[] memory balancesBefore = new uint256[](assetCount);
        for (uint256 i = 0; i < assetCount;) {
            if (address(beaconChainETHStrategy) != address(withdrawal.strategies[i])) {
                lrtUnstakingVault.reduceSharesUnstaking(address(assets[i]), withdrawal.shares[i]);
            } else {
                lrtUnstakingVault.reduceSharesUnstaking(LRTConstants.ETH_TOKEN, withdrawal.shares[i]);
            }
            if (receiveAsTokens) {
                if (address(beaconChainETHStrategy) != address(withdrawal.strategies[i])) {
                    balancesBefore[i] = assets[i].balanceOf(address(this));
                } else {
                    balancesBefore[i] = address(this).balance;
                }
            }
            unchecked {
                i++;
            }
        }

        // Finalize withdrawal with Eigenlayer Delegation Manager
        IDelegationManager(elDelegationManagerAddr).completeQueuedWithdrawal(
            withdrawal, assets, middlewareTimesIndex, receiveAsTokens
        );
        if (receiveAsTokens) {
            for (uint256 i = 0; i < assetCount;) {
                if (address(beaconChainETHStrategy) != address(withdrawal.strategies[i])) {
                    uint256 amount = assets[i].balanceOf(address(this)) - balancesBefore[i];
                    assets[i].transfer(lrtUnstakingVaultAddr, amount);
                }
                unchecked {
                    i++;
                }
            }
        }

        emit EigenLayerWithdrawalCompleted(withdrawal.staker, withdrawal.nonce, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                    Operational Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Sends ETH from the LRT deposit pool to this contract
    function sendETHFromDepositPoolToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        if (msg.sender != lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL)) {
            revert InvalidETHSender();
        }

        emit ETHDepositFromDepositPool(msg.value);
    }

    /// @notice Sends ETH from the LRT Unstaking Vault to this contract
    function sendETHFromUnstakingVaultToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        if (msg.sender != lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT)) {
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
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);

        if (asset == LRTConstants.ETH_TOKEN) {
            ILRTDepositPool(lrtDepositPool).receiveFromNodeDelegator{ value: amount }();
            emit EthTransferred(lrtDepositPool, amount);
        } else {
            IERC20(asset).safeTransfer(lrtDepositPool, amount);
        }
    }

    /// @notice Transfers ETH back to the LRT Unstaking Vault
    /// @dev only supported assets can be transferred and only called by the LRT manager
    /// @param amount the amount to transfer
    function transferETHToLRTUnstakingVault(uint256 amount) external nonReentrant whenNotPaused onlyLRTOperator {
        address lrtUnstakingVault = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        ILRTUnstakingVault(lrtUnstakingVault).receiveFromNodeDelegator{ value: amount }();
        emit EthTransferred(lrtUnstakingVault, amount);
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
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);
        IERC20(asset).approve(eigenlayerStrategyManagerAddress, type(uint256).max);
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

    function increaseLastNonce() external override {
        if (lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT) != msg.sender) {
            revert CallerNotLRTUnstakingVault();
        }
        lastNonce = lastNonce + 1;
    }

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/
    function hasAllWithdrawalsAccounted() public view override returns (bool) {
        return (getNonce() == lastNonce);
    }

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getAssetBalances() external view override returns (address[] memory, uint256[] memory) {
        return ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT)).getStakedAssetBalances(
            address(this)
        );
    }

    /// @dev Returns the balance of an asset that the node delegator has deposited into the strategy
    /// @param asset the asset to get the balance of
    /// @return stakedBalance the balance of the asset
    function getAssetBalance(address asset) external view override returns (uint256) {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            return 0;
        }

        return IStrategy(strategy).userUnderlyingView(address(this));
    }

    /// @dev Returns the amount of eth staked in eigenlayer through this ndc
    function getEffectivePodShares() external view override returns (int256 ethStaked) {
        int256 nativeEthShares =
            IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER)).podOwnerShares(address(this));

        // if the below sum becomes negative, it will be balanced by sharesUnstaking when computing total TVL
        return SafeCast.toInt256(stakedButUnverifiedNativeETH) + nativeEthShares;
    }

    function elOperatorDelegatedTo() external view override returns (address) {
        return
            IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER)).delegatedTo(address(this));
    }

    function getNonce() internal view returns (uint256) {
        return IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER))
            .cumulativeWithdrawalsQueued(address(this));
    }
}
