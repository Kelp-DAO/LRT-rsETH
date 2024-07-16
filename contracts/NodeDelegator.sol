// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

// openzeppelin or other standard contracts
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// external libraries, interfaces, contracts
import { BeaconChainProofs } from "./external/eigenlayer/libraries/BeaconChainProofs.sol";

import { IEigenPod, IBeaconDeposit } from "./external/eigenlayer/interfaces/IEigenPod.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { IEigenStrategyManager } from "./external/eigenlayer/interfaces/IEigenStrategyManager.sol";
import { IEigenPodManager } from "./external/eigenlayer/interfaces/IEigenPodManager.sol";
import { IEigenDelegationManager } from "./external/eigenlayer/interfaces/IEigenDelegationManager.sol";
import { IEigenDelayedWithdrawalRouter } from "./external/eigenlayer/interfaces/IEigenDelayedWithdrawalRouter.sol";

// protocol libraries, interfaces, contracts
import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker } from "./utils/LRTConfigRoleChecker.sol";

import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IFeeReceiver } from "./interfaces/IFeeReceiver.sol";

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
    address public elOperatorDelegatedTo;

    /// @dev amount of eth expected to receive from extra eth staked for validators
    uint256 public extraStakeToReceive;

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

    /// @dev due to a bit heavy logic, eth transfer using `transfer()` and `send()` will fail
    /// @dev hence please use `call()` to send eth to this contract
    receive() external payable {
        if (msg.sender != address(eigenPod)) {
            // then these are extraStakes or rewards
            uint256 extraStakeReceived = UtilLib.getMin(msg.value, extraStakeToReceive);
            _reduceExtraStakes(extraStakeReceived);

            // rest are rewards
            _sendRewardsToRewardReceiver(msg.value - extraStakeReceived);
        }
        // else if received from eigenPod
        // then these are assumed to be exit validators' eth
        // just receive it here
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
        IEigenDelegationManager.SignatureWithExpiry memory approverSignatureAndExpiry,
        bytes32 approverSalt
    )
        external
        onlyLRTManager
    {
        UtilLib.checkNonZeroAddress(elOperator);
        elOperatorDelegatedTo = elOperator;

        IEigenDelegationManager elDelegationManager =
            IEigenDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
        elDelegationManager.delegateTo(elOperator, approverSignatureAndExpiry, approverSalt);
        emit ElSharesDelegated(elOperator);
    }

    function createEigenPod() external onlyLRTManager {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.createPod();
        eigenPod = eigenPodManager.ownerToPod(address(this));

        emit EigenPodCreated(address(eigenPod), address(this));
    }

    /// @dev activates eigenPod, i.e. enables all M2 functions
    /// restricts execution of few functions, check `hasEnabledRestaking` modifier in EigenPod
    /// NOTE: creates a delayedWithdrawal for the eth accumulated on eigenPod (skimmed from beacon chain)
    /// NOTE: newly created M2 pods are already activated
    function activateRestaking() external onlyLRTManager {
        eigenPod.activateRestaking();
        emit RestakingActivated();
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
        external
        whenNotPaused
        onlyLRTOperator
    {
        // tracks staked but unverified native ETH
        stakedButUnverifiedNativeETH += 32 ether;

        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

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
        IBeaconDeposit depositContract = eigenPod.ethPOS();
        bytes32 actualDepositRoot = depositContract.get_deposit_root();
        if (expectedDepositRoot != actualDepositRoot) {
            revert InvalidDepositRoot(expectedDepositRoot, actualDepositRoot);
        }

        // tracks staked but unverified native ETH
        stakedButUnverifiedNativeETH += 32 ether;

        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        eigenPodManager.stake{ value: 32 ether }(pubkey, signature, depositDataRoot);

        emit ETHStaked(pubkey, 32 ether);
    }

    /**
     * @notice This function verifies that the withdrawal credentials of validator(s) owned by the this NDC are pointed
     * to EigenPod. It also verifies the effective balance of the validator.  It verifies the provided proof of the
     * ETH validator against the beacon chain state root, marks the validator as 'active' in EigenLayer, and credits the
     * restaked ETH in Eigenlayer.
     * @param oracleTimestamp is the Beacon Chain timestamp whose state root the `proof` will be proven against.
     * @param validatorIndices is the list of indices of the validators being proven, refer to consensus specs
     * @param withdrawalCredentialProofs is an array of proofs, where each proof proves each ETH validator's balance and
     * withdrawal credentials against a beacon chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata withdrawalCredentialProofs,
        bytes32[][] calldata validatorFields
    )
        external
        onlyLRTOperator
    {
        // reduce the eth amount that is verified
        stakedButUnverifiedNativeETH -= (validatorFields.length * (32 ether));

        eigenPod.verifyWithdrawalCredentials(
            oracleTimestamp, stateRootProof, validatorIndices, withdrawalCredentialProofs, validatorFields
        );
    }

    /// @notice undelegates from operator and removes all currently active shares
    function undelegate() external whenNotPaused onlyLRTManager {
        elOperatorDelegatedTo = address(0);

        IEigenDelegationManager elDelegationManager =
            IEigenDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
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

        uint256 nonce = elDelegationManager.cumulativeWithdrawalsQueued(address(this));
        bytes32[] memory withdrawalRoots = elDelegationManager.undelegate(address(this));

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
        public
        override
        nonReentrant
        whenNotPaused
        onlyLRTOperator
        returns (bytes32 withdrawalRoot)
    {
        IEigenDelegationManager.QueuedWithdrawalParams memory queuedWithdrawalParam = IEigenDelegationManager
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
        address elDelegationManagerAddr = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IEigenDelegationManager elDelegationManager = IEigenDelegationManager(elDelegationManagerAddr);

        IEigenDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawalParams =
            new IEigenDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawalParams[0] = queuedWithdrawalParam;
        uint256 nonce = elDelegationManager.cumulativeWithdrawalsQueued(address(this));
        bytes32[] memory withdrawalRoots = elDelegationManager.queueWithdrawals(queuedWithdrawalParams);
        withdrawalRoot = withdrawalRoots[0];

        emit WithdrawalQueued(nonce, address(this), withdrawalRoots);
    }

    /// @notice Finalizes Eigenlayer withdrawal to enable processing of queued withdrawals
    /// @param withdrawal Struct containing all data for the withdrawal
    /// @param assets Array specifying the `token` input for each strategy's 'withdraw' function.
    /// @param middlewareTimesIndex Index in the middleware times array for withdrawal eligibility check.
    function completeUnstaking(
        IEigenDelegationManager.Withdrawal calldata withdrawal,
        IERC20[] calldata assets,
        uint256 middlewareTimesIndex
    )
        external
        nonReentrant
        whenNotPaused
        onlyLRTOperator
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
            lrtUnstakingVault.reduceSharesUnstaking(address(assets[i]), withdrawal.shares[i]);
            if (address(beaconChainETHStrategy) != address(withdrawal.strategies[i])) {
                balancesBefore[i] = assets[i].balanceOf(address(this));
            } else {
                balancesBefore[i] = address(this).balance;
            }
            unchecked {
                i++;
            }
        }

        // Finalize withdrawal with Eigenlayer Delegation Manager
        IEigenDelegationManager(elDelegationManagerAddr).completeQueuedWithdrawal(
            withdrawal, assets, middlewareTimesIndex, true
        );

        for (uint256 i = 0; i < assetCount;) {
            if (address(beaconChainETHStrategy) != address(withdrawal.strategies[i])) {
                uint256 amount = assets[i].balanceOf(address(this)) - balancesBefore[i];
                assets[i].transfer(lrtUnstakingVaultAddr, amount);
            }
            unchecked {
                i++;
            }
        }
        emit EigenLayerWithdrawalCompleted(withdrawal.staker, withdrawal.nonce, msg.sender);
    }

    /// @notice initiate a delayed withdraw of ETH available at eigenPod
    /// @dev this eth will be available to claim after withdrawalDelay blocks
    /// @dev this method will be deprecated once eigenPod is activated
    /// TODO: remove this function after eigenPod activation
    function withdrawBeforeRestaking() external onlyLRTOperator {
        eigenPod.withdrawBeforeRestaking();
    }

    /// @notice claim delayed withdrawal entries (rewards + extraStakes)
    /// @param maxNumberOfDelayedWithdrawalsToClaim the max number of delayed withdrawals to claim
    /// @dev available to claim after a waiting period of withdrawalBlockDelay set by eigenLayer
    /// @dev permissionless call
    function claimDelayedWithdrawals(uint256 maxNumberOfDelayedWithdrawalsToClaim) external {
        address delayedRouterAddr = eigenPod.delayedWithdrawalRouter();
        IEigenDelayedWithdrawalRouter elDelayedRouter = IEigenDelayedWithdrawalRouter(delayedRouterAddr);
        elDelayedRouter.claimDelayedWithdrawals(address(this), maxNumberOfDelayedWithdrawalsToClaim);
    }

    /*//////////////////////////////////////////////////////////////
                    Operational Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Sends ETH from the LRT deposit pool to this contract
    function sendETHFromDepositPoolToNDC() external payable override {
        // only allow LRT deposit pool to send ETH to this contract
        address lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        if (msg.sender != lrtDepositPool) {
            revert InvalidETHSender();
        }

        emit ETHDepositFromDepositPool(msg.value);
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
        onlyLRTManager
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
    function transferETHToLRTUnstakingVault(uint256 amount) external nonReentrant whenNotPaused onlyLRTManager {
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

    /// @dev increments the amount of eth expected to receive from extra eth staked for validators
    /// @param amount the amount to increment
    function incrementExtraStakeToReceive(uint256 amount) external onlyLRTOperator {
        extraStakeToReceive += amount;
        if (extraStakeToReceive > stakedButUnverifiedNativeETH) {
            revert InsufficientStakedButUnverifiedNativeETH();
        }
        emit ETHExtraStakeToReceiveIncremented(amount);
    }

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

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getAssetBalances()
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        address eigenlayerStrategyManagerAddress = lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER);

        (IStrategy[] memory strategies,) =
            IEigenStrategyManager(eigenlayerStrategyManagerAddress).getDeposits(address(this));

        uint256 strategiesLength = strategies.length;
        assets = new address[](strategiesLength);
        assetBalances = new uint256[](strategiesLength);

        for (uint256 i = 0; i < strategiesLength;) {
            assets[i] = address(IStrategy(strategies[i]).underlyingToken());
            assetBalances[i] = IStrategy(strategies[i]).userUnderlyingView(address(this));
            unchecked {
                ++i;
            }
        }
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
    function getETHEigenPodBalance() external view override returns (uint256 ethStaked) {
        IEigenPodManager eigenPodManager = IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
        int256 nativeEthShares = eigenPodManager.podOwnerShares(address(this));

        if (nativeEthShares < 0) {
            // native eth shares are negative due to slashing and queue of more amount of eth withdrawal
            uint256 nativeEthSharesDeficit = uint256(-nativeEthShares);
            if (nativeEthSharesDeficit > stakedButUnverifiedNativeETH) {
                return 0;
            } else {
                return stakedButUnverifiedNativeETH - nativeEthSharesDeficit;
            }
        }

        return stakedButUnverifiedNativeETH + uint256(nativeEthShares);
    }

    /*//////////////////////////////////////////////////////////////
                            internal functions
    //////////////////////////////////////////////////////////////*/

    function _reduceExtraStakes(uint256 extraStakeReceived) internal {
        if (extraStakeReceived <= 0) return;

        extraStakeToReceive -= extraStakeReceived;
        stakedButUnverifiedNativeETH -= extraStakeReceived;
        emit ExtraStakeReceived(extraStakeReceived);
    }

    function _sendRewardsToRewardReceiver(uint256 rewardsAmount) internal {
        if (rewardsAmount == 0) return;

        address rewardReceiver = lrtConfig.getContract(LRTConstants.REWARD_RECEIVER);
        IFeeReceiver(rewardReceiver).receiveFromNodeDelegator{ value: rewardsAmount }();
        emit ETHRewardsReceived(rewardsAmount);
    }
}
