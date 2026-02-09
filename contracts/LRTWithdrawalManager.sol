// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { DoubleEndedQueue } from "./utils/DoubleEndedQueue.sol";

import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";
import { IRSETH } from "./interfaces/IRSETH.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { ILRTWithdrawalManager } from "./interfaces/ILRTWithdrawalManager.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IWrappedTokenGatewayV3 } from "./interfaces/aave/IWrappedTokenGatewayV3.sol";
import { IAToken } from "./interfaces/aave/IAToken.sol";
import { IPoolDataProvider } from "./interfaces/aave/IPoolDataProvider.sol";

/// @title LRTWithdrawalManager - Withdraw Manager Contract for rsETH => LSTs
/// @notice Handles LST asset withdraws
contract LRTWithdrawalManager is
    ILRTWithdrawalManager,
    LRTConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using DoubleEndedQueue for DoubleEndedQueue.Uint256Deque;
    using SafeERC20 for IERC20;

    mapping(address asset => uint256) public minRsEthAmountToWithdraw;
    uint256 public withdrawalDelayBlocks;

    // Next available nonce for withdrawal requests per asset, indicating total requests made.
    mapping(address asset => uint256 nonce) public nextUnusedNonce;

    // Next nonce for which a withdrawal request remains locked.
    mapping(address asset => uint256 requestNonce) public nextLockedNonce;

    // Mapping from a unique request identifier to its corresponding withdrawal request
    mapping(bytes32 requestId => WithdrawalRequest) public withdrawalRequests;

    // Maps each asset to user addresses, pointing to an ordered list of their withdrawal request nonces.
    // Utilizes a double-ended queue for efficient management and removal of initial requests.
    mapping(address asset => mapping(address user => DoubleEndedQueue.Uint256Deque requestNonces)) public
        userAssociatedNonces;

    // Asset amount committed to be withdrawn by users.
    mapping(address asset => uint256 amount) public assetsCommitted;

    mapping(address asset => bool) public isInstantWithdrawalEnabled;
    uint256 public instantWithdrawalFee; // Fee in basis points (1 = 0.01%)

    mapping(address asset => uint256) public unlockedWithdrawalsCount;

    IWrappedTokenGatewayV3 public aaveWETHGateway;
    IAToken public aaveAWETH;
    address public aavePool;
    IPoolDataProvider public aaveDataProvider;
    bool public isAaveIntegrationEnabled;
    uint256 public totalETHDepositedToAave;
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Address that receives instant withdrawal fees. If unset, fees go to the protocol treasury.
    address public instantWithdrawalFeeRecipient;

    modifier onlySupportedStrategy(address asset) {
        if (asset != LRTConstants.ETH_TOKEN && lrtConfig.assetStrategy(asset) == address(0)) {
            revert StrategyNotSupported();
        }
        _;
    }

    modifier onlyInstantWithdrawalAllowed(address asset) {
        if (!isInstantWithdrawalEnabled[asset]) revert InstantWithdrawalNotEnabled();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();
        withdrawalDelayBlocks = 8 days / 12 seconds;

        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /// @notice Initializes unlocked withdrawals count for ETHx, STETH and ETH
    /// @dev Upgrade-only reinitializer used to seed `unlockedWithdrawalsCount` for the existing deployments.
    ///      Can be called exactly once and only by the UNLOCKED_WITHDRAWAL_INITIALIZER role.
    ///      After this call, the per-asset `unlockedWithdrawalsCount` is only changed by the normal
    ///      withdrawal lifecycle and cannot be manually overridden. New deployments MUST NOT call
    ///      this function, as they are expected to start from zero unlocked withdrawals.
    /// @param unlockedWithdrawalsCountETHx Initial unlocked withdrawals count for ETHx
    /// @param unlockedWithdrawalsCountSTETH Initial unlocked withdrawals count for STETH
    /// @param unlockedWithdrawalsCountETH Initial unlocked withdrawals count for ETH
    function initialize2(
        uint256 unlockedWithdrawalsCountETHx,
        uint256 unlockedWithdrawalsCountSTETH,
        uint256 unlockedWithdrawalsCountETH
    )
        external
        reinitializer(2)
        onlyRole(LRTConstants.UNLOCKED_WITHDRAWAL_INITIALIZER)
    {
        unlockedWithdrawalsCount[lrtConfig.getLSTToken(LRTConstants.ST_ETH_TOKEN)] = unlockedWithdrawalsCountSTETH;
        unlockedWithdrawalsCount[lrtConfig.getLSTToken(LRTConstants.ETHX_TOKEN)] = unlockedWithdrawalsCountETHx;
        unlockedWithdrawalsCount[LRTConstants.ETH_TOKEN] = unlockedWithdrawalsCountETH;
    }

    /// @notice Initializes unlocked withdrawals count for sfrxETH for legacy purposes
    /// @dev This function will be removed in a future version
    /// @param unlockedWithdrawalsCountSFRXETH The remaining unlocked withdrawals count for sfrxETH
    function initialize3(uint256 unlockedWithdrawalsCountSFRXETH) external reinitializer(3) onlyLRTManager {
        address sfrxETHAddress = 0xac3E018457B222d93114458476f3E3416Abbe38F;
        unlockedWithdrawalsCount[sfrxETHAddress] = unlockedWithdrawalsCountSFRXETH;
    }

    /*//////////////////////////////////////////////////////////////
                        receive functions
    //////////////////////////////////////////////////////////////*/

    receive() external payable { }

    /// @dev receive from LRTUnstakingVault
    function receiveFromLRTUnstakingVault() external payable { }

    /*//////////////////////////////////////////////////////////////
                        User Withdrawal functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Initiates a withdrawal request for converting rsETH to a specified LST.
    /// @param asset The LST address the user wants to receive.
    /// @param rsETHUnstaked The amount of rsETH the user wishes to unstake.
    /// @dev This function is only callable by the user and is used to initiate a withdrawal request for a specific
    /// asset. Will be finalised by calling `completeWithdrawal` after the manager unlocked the request and the delay
    /// has past. There is an edge case were the user withdraws last underlying asset and that asset gets slashed.
    function initiateWithdrawal(
        address asset,
        uint256 rsETHUnstaked,
        string calldata referralId
    )
        external
        override
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
        onlySupportedStrategy(asset)
    {
        if (rsETHUnstaked == 0 || rsETHUnstaked < minRsEthAmountToWithdraw[asset]) {
            revert InvalidAmountToWithdraw();
        }

        IERC20(lrtConfig.rsETH()).safeTransferFrom(msg.sender, address(this), rsETHUnstaked);

        uint256 expectedAssetAmount = getExpectedAssetAmount(asset, rsETHUnstaked);

        if (expectedAssetAmount > getAvailableAssetAmount(asset)) revert ExceedAmountToWithdraw();

        // preventing over-withdrawal.
        assetsCommitted[asset] += expectedAssetAmount;

        _addUserWithdrawalRequest(asset, rsETHUnstaked, expectedAssetAmount);

        emit ReferralIdEmitted(referralId);
    }

    /// @notice Completes a user's withdrawal process by transferring the ETH/LST amount corresponding to the rsETH
    /// unstaked.
    /// @param asset The asset address the user wishes to withdraw.
    function completeWithdrawal(address asset, string calldata referralId) external nonReentrant whenNotPaused {
        _processWithdrawalCompletion(asset, msg.sender, referralId);
    }

    /// @notice Allows operators to complete a user's withdrawal process
    /// @param asset The asset address the user wishes to withdraw
    /// @param user The address of the user whose withdrawal to complete
    /// @param referralId The referral identifier for tracking
    /// @dev Not expected to be used for ETH; potential gas grief scenarios are non-impactful for ETH
    function completeWithdrawalForUser(
        address asset,
        address user,
        string calldata referralId
    )
        external
        nonReentrant
        whenNotPaused
        onlyLRTOperator
    {
        _processWithdrawalCompletion(asset, user, referralId);
        emit AssetWithdrawalCompletedBy(msg.sender);
    }

    /// @notice Allows users to instantly withdraw their assets by burning rsETH tokens
    /// @param asset The address of the asset (ETH/LST) to withdraw
    /// @param rsETHUnstaked The amount of rsETH tokens to burn for withdrawal
    /// @param referralId The referral identifier for tracking
    /// @dev Uses the fee set at execution time. Managers can raise it right before this call, making withdrawals cost
    /// more than expected.
    function instantWithdrawal(
        address asset,
        uint256 rsETHUnstaked,
        string calldata referralId
    )
        external
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
        onlySupportedStrategy(asset)
        onlyInstantWithdrawalAllowed(asset)
    {
        if (rsETHUnstaked == 0 || rsETHUnstaked < minRsEthAmountToWithdraw[asset]) {
            revert InvalidAmountToWithdraw();
        }
        if (IERC20(lrtConfig.rsETH()).balanceOf(msg.sender) < rsETHUnstaked) revert NotEnoughRsETH();
        uint256 assetAmountUnlocked = getExpectedAssetAmount(asset, rsETHUnstaked);
        IRSETH(lrtConfig.rsETH()).burnFrom(address(msg.sender), rsETHUnstaked);
        ILRTUnstakingVault unstakingVault = ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));
        if (assetAmountUnlocked > unstakingVault.getAssetsAvailableForInstantWithdrawal(asset)) {
            revert CantInstantWithdrawMoreThanAvailable();
        }

        unstakingVault.redeem(asset, assetAmountUnlocked);

        uint256 fee = (assetAmountUnlocked * instantWithdrawalFee) / 10_000;
        uint256 userAmount = assetAmountUnlocked - fee;

        address feeRecipient = instantWithdrawalFeeRecipient;
        if (feeRecipient == address(0)) {
            // Backwards-compatible default: send fees to the protocol treasury
            feeRecipient = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
        }
        if (fee > 0) {
            _transferAsset(asset, feeRecipient, fee);
            emit InstantWithdrawalFeeCollected(msg.sender, asset, fee);
        }

        _transferAsset(asset, msg.sender, userAmount);
        emit ReferralIdEmitted(referralId);
        emit AssetWithdrawalFinalized(msg.sender, asset, rsETHUnstaked, userAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        operational functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Unlocks assets in the queue up to a specified limit.
    /// @dev If Aave integration is enabled, this function may attempt a self-call that deposits into Aave.
    ///      Callers should make sure they are using a sufficiently high gas limit.
    /// @param asset The address of the asset to unlock.
    /// @param firstExcludedIndex First withdrawal requests index that will not be considered for unlocking.
    /// @param minimumAssetPrice The minimum acceptable price for the asset.
    /// @param minimumRsEthPrice The minimum acceptable price for rsETH.
    /// @param maximumAssetPrice The maximum acceptable price for the asset.
    /// @param maximumRsEthPrice The maximum acceptable price for rsETH.
    function unlockQueue(
        address asset,
        uint256 firstExcludedIndex,
        uint256 minimumAssetPrice,
        uint256 minimumRsEthPrice,
        uint256 maximumAssetPrice,
        uint256 maximumRsEthPrice
    )
        external
        nonReentrant
        onlySupportedAsset(asset)
        whenNotPaused
        onlyAssetTransferOrOperatorRole
        returns (uint256 rsETHBurned, uint256 assetAmountUnlocked)
    {
        ILRTOracle lrtOracle = ILRTOracle(lrtConfig.getContract(LRTConstants.LRT_ORACLE));
        ILRTUnstakingVault unstakingVault = ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));

        UnlockParams memory params = _createUnlockParams(lrtOracle, unstakingVault, asset);

        _validatePrices(
            params.rsETHPrice,
            params.assetPrice,
            minimumRsEthPrice,
            maximumRsEthPrice,
            minimumAssetPrice,
            maximumAssetPrice
        );

        if (params.totalAvailableAssets == 0) revert AmountMustBeGreaterThanZero();

        // Updates and unlocks withdrawal requests up to a specified upper limit or until allocated assets are fully
        // utilized.
        (rsETHBurned, assetAmountUnlocked) = _unlockWithdrawalRequests(
            asset, params.totalAvailableAssets, params.rsETHPrice, params.assetPrice, firstExcludedIndex
        );

        if (rsETHBurned != 0) IRSETH(lrtConfig.rsETH()).burnFrom(address(this), rsETHBurned);
        //Take the amount to distribute from vault
        unstakingVault.redeem(asset, assetAmountUnlocked);

        // If Aave integration is enabled and asset is ETH, deposit to Aave
        if (isAaveIntegrationEnabled && asset == LRTConstants.ETH_TOKEN && assetAmountUnlocked > 0) {
            try this.depositToAaveExternal(assetAmountUnlocked) { }
            catch (bytes memory reason) {
                emit AaveDepositFailed(assetAmountUnlocked, reason);
                // Silently fail if Aave deposit fails (e.g., pool at max capacity)
                // Funds remain in contract for withdrawals
            }
        }

        emit AssetUnlocked(asset, rsETHBurned, assetAmountUnlocked, params.rsETHPrice, params.assetPrice);
    }

    /*//////////////////////////////////////////////////////////////
                    Manager And Admin Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice update min amount to withdraw
    /// @dev only callable by LRT admin
    /// @param asset Asset address
    /// @param minRsEthAmountToWithdraw_ Minimum amount to withdraw
    function setMinRsEthAmountToWithdraw(address asset, uint256 minRsEthAmountToWithdraw_) external onlyLRTAdmin {
        minRsEthAmountToWithdraw[asset] = minRsEthAmountToWithdraw_;
        emit MinAmountToWithdrawUpdated(asset, minRsEthAmountToWithdraw_);
    }

    /// @notice update withdrawal delay
    /// @dev only callable by LRT manager
    /// @param withdrawalDelayBlocks_ The amount of blocks to wait till to complete a withdraw
    function setWithdrawalDelayBlocks(uint256 withdrawalDelayBlocks_) external onlyLRTManager {
        // Set an upper limit of no more than 16 days
        if (withdrawalDelayBlocks_ > 16 days / 12 seconds) revert ExceedWithdrawalDelay();

        withdrawalDelayBlocks = withdrawalDelayBlocks_;
        emit WithdrawalDelayBlocksUpdated(withdrawalDelayBlocks);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyRole(LRTConstants.PAUSER_ROLE) {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused.
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /// @notice Enables or disables instant withdrawal for a specific asset
    /// @param asset The asset address to configure
    /// @param enabled Whether instant withdrawal should be enabled
    /// @dev Only callable by LRTManager
    function setInstantWithdrawalEnabled(address asset, bool enabled)
        external
        onlySupportedAsset(asset)
        onlyLRTManager
    {
        isInstantWithdrawalEnabled[asset] = enabled;
        emit InstantWithdrawalEnabledUpdated(asset, enabled);
    }

    /// @notice Sets the instant withdrawal fee
    /// @param feeBasisPoints The fee in basis points (1 = 0.01%)
    /// @dev Only callable by LRTManager
    function setInstantWithdrawalFee(uint256 feeBasisPoints) external onlyLRTManager {
        if (feeBasisPoints > 1000) revert FeeTooHigh(); // Max 10%
        instantWithdrawalFee = feeBasisPoints;
        emit InstantWithdrawalFeeUpdated(feeBasisPoints);
    }

    /// @notice Sets the recipient of instant withdrawal fees
    /// @param feeRecipient The address that will receive instant withdrawal fees
    /// @dev Only callable by LRTManager. The zero address is intentionally disallowed to avoid confusion.
    ///      To route fees to the protocol treasury, LRTManager must explicitly set the PROTOCOL_TREASURY
    ///      address as the fee recipient. When `instantWithdrawalFeeRecipient` is unset (zero) internally,
    ///      fees flow to the treasury by default for backwards compatibility.
    function setInstantWithdrawalFeeRecipient(address feeRecipient) external onlyLRTManager {
        UtilLib.checkNonZeroAddress(feeRecipient);
        instantWithdrawalFeeRecipient = feeRecipient;
        emit InstantWithdrawalFeeRecipientUpdated(feeRecipient);
    }

    /// @notice Sweep remaining assets to treasury when all withdrawals are completed
    /// @param asset The asset address to sweep
    /// @return transferredAmount The amount swept to treasury
    /// @dev This function can only be called when no unlocked withdrawals exist for the asset
    /// @dev Not expected to be used for ETH; ETH should not accumulate requiring sweeping
    function sweepRemainingAssets(address asset)
        external
        nonReentrant
        onlySupportedAsset(asset)
        onlyLRTManager
        returns (uint256 transferredAmount)
    {
        // Check that all withdrawals are completed
        if (hasUnlockedWithdrawals(asset)) revert PendingWithdrawalsExist();

        uint256 balance = _getAssetBalance(asset);
        if (balance == 0) revert AmountMustBeGreaterThanZero();

        // Transfer to treasury
        address treasury = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
        _transferAsset(asset, treasury, balance);

        emit RemainingAssetsSwept(asset, balance, treasury);
        return balance;
    }

    /// @notice Configure Aave v3 integration addresses
    /// @param aavePool_ Address of Aave v3 Pool contract
    /// @param aaveWETHGateway_ Address of Aave v3 WETH Gateway contract
    /// @param aaveAWETH_ Address of Aave v3 aWETH token
    /// @param aaveDataProvider_ Address of Aave v3 Pool Data Provider contract
    /// @dev Only callable by LRT manager
    function configureAaveIntegration(
        address aavePool_,
        address aaveWETHGateway_,
        address aaveAWETH_,
        address aaveDataProvider_
    )
        external
        nonReentrant
        onlyLRTManager
    {
        UtilLib.checkNonZeroAddress(aavePool_);
        UtilLib.checkNonZeroAddress(aaveWETHGateway_);
        UtilLib.checkNonZeroAddress(aaveAWETH_);
        UtilLib.checkNonZeroAddress(aaveDataProvider_);

        // If reconfiguring an existing Aave integration, collect interest and withdraw all funds first
        if (address(aaveAWETH) != address(0) && address(aaveWETHGateway) != address(0) && aavePool != address(0)) {
            uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
            if (aaveBalance > 0) {
                // First collect any accrued interest to treasury
                _collectInterestToTreasury();

                // Then withdraw all remaining principal from old Aave pool
                aaveBalance = aaveAWETH.balanceOf(address(this));
                if (aaveBalance > 0) {
                    _withdrawFromAave(aaveBalance);
                }
            }

            // Revoke approval for old aWETH token
            IERC20(address(aaveAWETH)).forceApprove(address(aaveWETHGateway), 0);
        }

        aavePool = aavePool_;
        aaveWETHGateway = IWrappedTokenGatewayV3(aaveWETHGateway_);
        aaveAWETH = IAToken(aaveAWETH_);
        aaveDataProvider = IPoolDataProvider(aaveDataProvider_);

        // Approve aWETH to WETH Gateway for withdrawals
        IERC20(aaveAWETH_).forceApprove(aaveWETHGateway_, type(uint256).max);

        emit AaveIntegrationConfigured(aavePool_, aaveWETHGateway_, aaveAWETH_, aaveDataProvider_);
    }

    /// @notice Enable or disable Aave integration
    /// @param enabled Whether Aave integration should be enabled
    /// @dev Only callable by LRT manager
    function setAaveIntegrationEnabled(bool enabled) external nonReentrant onlyLRTManager {
        if (enabled == isAaveIntegrationEnabled) {
            revert AaveIntegrationAlreadyInDesiredState(enabled);
        }

        if (enabled) {
            if (
                address(aaveWETHGateway) == address(0) || address(aaveAWETH) == address(0) || aavePool == address(0)
                    || address(aaveDataProvider) == address(0)
            ) {
                revert InvalidAaveConfiguration();
            }

            // Approve aWETH to WETH Gateway for withdrawals
            IERC20(address(aaveAWETH)).forceApprove(address(aaveWETHGateway), type(uint256).max);
        }

        if (!enabled) {
            uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
            if (aaveBalance > 0) {
                // First collect any accrued interest to treasury
                _collectInterestToTreasury();

                // Then withdraw remaining principal from Aave back to contract
                aaveBalance = aaveAWETH.balanceOf(address(this));
                if (aaveBalance > 0) {
                    _withdrawFromAave(aaveBalance);
                }
            }

            // Revoke approval for aWETH token to Aave WETH Gateway
            _revokeApprovalToAaveWETHGateway();
        }

        isAaveIntegrationEnabled = enabled;
        emit AaveIntegrationEnabled(enabled);
    }

    /// @notice External wrapper for depositing to Aave (used for try/catch in `unlockQueue`)
    /// @param amount Amount of ETH to deposit
    /// @dev Intentionally NOT `nonReentrant`. `unlockQueue()` is `nonReentrant` and calls this via an external
    ///      self-call (`this.depositToAaveExternal`) to enable try/catch. Marking this as `nonReentrant` would
    ///      make that path always revert due to the shared ReentrancyGuard status. Safety is enforced by
    ///     `msg.sender == address(this)` check.
    function depositToAaveExternal(uint256 amount) external {
        if (msg.sender != address(this)) revert UnauthorizedCaller();
        _depositToAave(amount);
    }

    /// @notice Manually deposit ETH to Aave
    /// @param amount Amount of ETH to deposit (use type(uint256).max for entire balance)
    /// @dev Only callable by LRT operator. Useful for depositing ETH that hasn't been auto-deposited yet
    function depositIdleETHToAave(uint256 amount) external nonReentrant whenNotPaused onlyLRTOperator {
        if (!isAaveIntegrationEnabled) revert AaveIntegrationNotEnabled();

        uint256 idleBalance = address(this).balance;
        if (idleBalance == 0) revert AmountMustBeGreaterThanZero();

        uint256 depositAmount = amount;
        if (amount == type(uint256).max || amount > idleBalance) {
            depositAmount = idleBalance;
        }

        if (depositAmount > 0) {
            _depositToAave(depositAmount);
        }
    }

    /// @notice Collect earned interest from Aave and send to treasury
    /// @return interestAmount The amount of interest collected
    /// @dev Only callable by LRT operator
    function collectInterestToTreasury() external nonReentrant onlyLRTOperator returns (uint256 interestAmount) {
        // Check health and revert if integration not enabled or unhealthy
        if (!_checkAaveHealth()) revert AaveHealthCheckFailed();

        return _collectInterestToTreasury();
    }

    /// @notice Emergency withdrawal from Aave in case of issues
    /// @param amount Amount to withdraw (use type(uint256).max for full withdrawal)
    /// @dev Only callable by PAUSER_ROLE
    /// @dev Collects accrued interest to treasury before withdrawing principal
    function emergencyWithdrawFromAave(uint256 amount) external nonReentrant onlyRole(LRTConstants.PAUSER_ROLE) {
        if (!isAaveIntegrationEnabled) revert AaveIntegrationNotEnabled();

        uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
        if (aaveBalance == 0) revert InsufficientAaveBalance();

        // First collect any accrued interest to treasury
        _collectInterestToTreasury();

        uint256 withdrawnAmount = _withdrawFromAave(amount);

        emit EmergencyWithdrawFromAave(withdrawnAmount, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Get request id
    /// @param asset Asset address
    /// @param requestIndex The requests index to generate id for
    function getRequestId(address asset, uint256 requestIndex) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(asset, requestIndex));
    }

    /// @notice Get asset amount to receive when trading in rsETH
    /// @param asset Asset address of LST to receive
    /// @param amount rsETH amount to convert
    /// @return underlyingToReceive Amount of underlying to receive
    function getExpectedAssetAmount(
        address asset,
        uint256 amount
    )
        public
        view
        override
        returns (uint256 underlyingToReceive)
    {
        // setup oracle contract
        ILRTOracle lrtOracle = ILRTOracle(lrtConfig.getContract(LRTConstants.LRT_ORACLE));

        // calculate underlying asset amount to receive based on rsETH amount and asset exchange rate
        underlyingToReceive = amount * lrtOracle.rsETHPrice() / lrtOracle.getAssetPrice(asset);
    }

    /// @notice Calculates the amount of asset available for withdrawal.
    /// @param asset The asset address.
    /// @return availableAssetAmount The asset amount avaialble for withdrawal.
    function getAvailableAssetAmount(address asset) public view override returns (uint256 availableAssetAmount) {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        uint256 totalAssets = lrtDepositPool.getTotalAssetDeposits(asset);
        availableAssetAmount = totalAssets > assetsCommitted[asset] ? totalAssets - assetsCommitted[asset] : 0;
    }

    /// @notice View user withdrawal request
    /// @param asset Asset address
    /// @param user User address
    /// @param userIndex Index in list of users withdrawal request
    function getUserWithdrawalRequest(
        address asset,
        address user,
        uint256 userIndex
    )
        public
        view
        override
        returns (uint256 rsETHAmount, uint256 expectedAssetAmount, uint256 withdrawalStartBlock, uint256 userNonce)
    {
        userNonce = userAssociatedNonces[asset][user].at(userIndex);
        bytes32 requestId = getRequestId(asset, userNonce);
        rsETHAmount = withdrawalRequests[requestId].rsETHUnstaked;
        expectedAssetAmount = withdrawalRequests[requestId].expectedAssetAmount;
        withdrawalStartBlock = withdrawalRequests[requestId].withdrawalStartBlock;
    }

    /// @notice Check if there are any unlocked withdrawals for a specific asset
    /// @param asset The asset address
    /// @return hasUnlocked True if there are unlocked withdrawals, false otherwise
    function hasUnlockedWithdrawals(address asset) public view returns (bool hasUnlocked) {
        return unlockedWithdrawalsCount[asset] > 0;
    }

    /// @notice Get the current balance of aWETH held by this contract
    /// @return balance The aWETH balance
    function getAaveBalance() public view returns (uint256 balance) {
        if (address(aaveAWETH) == address(0)) return 0;
        return aaveAWETH.balanceOf(address(this));
    }

    /// @notice Get the amount of interest accrued in Aave
    /// @return interest The interest amount (aWETH balance - deposited principal)
    /// @dev Returns 0 if aaveBalance < totalETHDepositedToAave (potential accounting issue)
    function getAccruedInterest() external view returns (uint256 interest) {
        uint256 aaveBalance = getAaveBalance();
        if (aaveBalance <= totalETHDepositedToAave) return 0;
        return aaveBalance - totalETHDepositedToAave;
    }

    /// @notice Check Aave balance health
    /// @return healthy True if Aave balance is healthy
    /// @dev Call this to verify accounting integrity. Should be monitored by operators.
    function aaveHealthCheck() external view returns (bool healthy) {
        return _checkAaveHealth();
    }

    /// @notice Get available capacity in Aave for WETH deposits
    /// @return availableCapacity The amount of WETH that can still be deposited to Aave
    /// @dev Returns 0 if Aave is not configured or if supply cap is reached
    function getAaveAvailableCapacity() external view returns (uint256 availableCapacity) {
        if (address(aaveAWETH) == address(0) || address(aaveDataProvider) == address(0)) {
            revert InvalidAaveConfiguration();
        }

        // Get supply cap from Aave Data Provider
        (, uint256 supplyCap) = aaveDataProvider.getReserveCaps(WETH_ADDRESS);

        // If supply cap is 0, it means unlimited capacity
        if (supplyCap == 0) return type(uint256).max;

        // Get current total supply of aWETH
        uint256 totalSupply = aaveAWETH.totalSupply();

        // Convert supply cap to wei and calculate available capacity
        uint256 supplyCapWei = supplyCap * 1e18;
        if (supplyCapWei > totalSupply) {
            availableCapacity = supplyCapWei - totalSupply;
        }
        // else returns 0 (pool is at or over capacity)
    }

    /// @notice Get withdrawable liquidity available in Aave
    /// @return withdrawableLiquidity The amount of WETH that can be withdrawn from Aave
    /// @dev This is the underlying WETH balance in the aWETH contract
    function getAaveWithdrawableLiquidity() external view returns (uint256 withdrawableLiquidity) {
        if (address(aaveAWETH) == address(0)) return 0;

        // The withdrawable liquidity is the WETH balance of the aWETH contract
        return IERC20(WETH_ADDRESS).balanceOf(address(aaveAWETH));
    }

    /*//////////////////////////////////////////////////////////////
                        internal functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes the completion of a withdrawal request for a user.
    /// @param asset The asset address of the withdrawal.
    /// @param user The address of the user whose withdrawal is being completed.
    /// @param referralId The referral identifier for tracking.
    function _processWithdrawalCompletion(address asset, address user, string calldata referralId) internal {
        if (userAssociatedNonces[asset][user].empty()) {
            revert NoWithdrawalRequests(user, asset);
        }

        // Retrieve and remove the oldest withdrawal request for the user.
        uint256 usersFirstWithdrawalRequestNonce = userAssociatedNonces[asset][user].popFront();
        // Ensure the request is already unlocked.
        if (usersFirstWithdrawalRequestNonce >= nextLockedNonce[asset]) revert WithdrawalLocked();

        bytes32 requestId = getRequestId(asset, usersFirstWithdrawalRequestNonce);
        WithdrawalRequest memory request = withdrawalRequests[requestId];

        delete withdrawalRequests[requestId];

        // Check that the withdrawal delay has passed since the request's initiation.
        if (block.number < request.withdrawalStartBlock + withdrawalDelayBlocks) revert WithdrawalDelayNotPassed();

        unlockedWithdrawalsCount[asset]--;

        // If Aave integration is enabled and asset is ETH, withdraw from Aave if needed
        if (isAaveIntegrationEnabled && asset == LRTConstants.ETH_TOKEN) {
            uint256 contractBalance = address(this).balance;
            if (contractBalance < request.expectedAssetAmount) {
                uint256 amountNeeded = request.expectedAssetAmount - contractBalance;
                _withdrawFromAave(amountNeeded);

                // Verify we have sufficient balance after withdrawal
                uint256 balanceAfter = address(this).balance;
                if (balanceAfter < request.expectedAssetAmount) {
                    revert InsufficientLiquidityForWithdrawal();
                }
            }
        }

        _transferAsset(asset, user, request.expectedAssetAmount);

        emit ReferralIdEmitted(referralId);
        emit AssetWithdrawalFinalized(user, asset, request.rsETHUnstaked, request.expectedAssetAmount);
    }

    /// @notice Registers a new request for withdrawing an asset in exchange for rsETH.
    /// @param asset The address of the asset being withdrawn.
    /// @param rsETHUnstaked The amount of rsETH being exchanged.
    /// @param expectedAssetAmount The expected amount of the asset to be received upon withdrawal completion.
    function _addUserWithdrawalRequest(address asset, uint256 rsETHUnstaked, uint256 expectedAssetAmount) internal {
        uint256 nextUnusedNonce_ = nextUnusedNonce[asset];

        // Generate a unique identifier for the new withdrawal request.
        bytes32 requestId = getRequestId(asset, nextUnusedNonce_);

        // Create and store the new withdrawal request.
        withdrawalRequests[requestId] = WithdrawalRequest({
            rsETHUnstaked: rsETHUnstaked, expectedAssetAmount: expectedAssetAmount, withdrawalStartBlock: block.number
        });

        // Map the user to the newly created request index and increment the nonce for future requests.
        userAssociatedNonces[asset][msg.sender].pushBack(nextUnusedNonce_);
        nextUnusedNonce[asset] = nextUnusedNonce_ + 1;

        emit AssetWithdrawalQueued(msg.sender, asset, rsETHUnstaked, nextUnusedNonce_);
    }

    /// @dev Unlocks user withdrawal requests based on current asset availability and prices.
    /// Iterates through pending requests and unlocks them until the provided asset amount is fully allocated.
    /// @param asset The asset's address for which withdrawals are being processed.
    /// @param rsETHPrice Current rsETH to ETH exchange rate.
    /// @param assetPrice Current asset to ETH exchange rate.
    /// @param firstExcludedIndex First withdrawal requests index that will not be considered for unlocking.
    /// @return rsETHAmountToBurn The total amount of rsETH unlocked for withdrawals.
    /// @return assetAmountToUnlock The total asset amount allocated to unlocked withdrawals.
    function _unlockWithdrawalRequests(
        address asset,
        uint256 availableAssetAmount,
        uint256 rsETHPrice,
        uint256 assetPrice,
        uint256 firstExcludedIndex
    )
        internal
        returns (uint256 rsETHAmountToBurn, uint256 assetAmountToUnlock)
    {
        // Check that upper limit is in the range of existing withdrawal requests. If it is greater set it to the first
        // nonce with no withdrawal request.
        if (firstExcludedIndex > nextUnusedNonce[asset]) {
            firstExcludedIndex = nextUnusedNonce[asset];
        }

        uint256 nextLockedNonce_ = nextLockedNonce[asset];
        // Revert when trying to unlock a request that has already been unlocked
        if (nextLockedNonce_ >= firstExcludedIndex) revert NoPendingWithdrawals();

        while (nextLockedNonce_ < firstExcludedIndex) {
            bytes32 requestId = getRequestId(asset, nextLockedNonce_);
            WithdrawalRequest storage request = withdrawalRequests[requestId];

            // Check that the withdrawal delay has passed since the request's initiation.
            if (block.number < request.withdrawalStartBlock + withdrawalDelayBlocks) break;

            // Calculate the amount user will receive
            uint256 payoutAmount = _calculatePayoutAmount(request, rsETHPrice, assetPrice);

            if (availableAssetAmount < payoutAmount) break; // Exit if not enough assets to cover this request

            assetsCommitted[asset] -= request.expectedAssetAmount;
            // Set the amount the user will receive
            request.expectedAssetAmount = payoutAmount;
            rsETHAmountToBurn += request.rsETHUnstaked;
            availableAssetAmount -= payoutAmount;
            assetAmountToUnlock += payoutAmount;

            unlockedWithdrawalsCount[asset]++;

            unchecked {
                nextLockedNonce_++;
            }
        }
        nextLockedNonce[asset] = nextLockedNonce_;
    }

    /// @notice Determines the final amount to be disbursed to the user, based on the lesser of the initially
    /// expected asset amount and the currently calculated return.
    /// @param request The specific withdrawal request being processed.
    /// @param rsETHPrice The latest exchange rate of rsETH to ETH.
    /// @param assetPrice The latest exchange rate of the asset to ETH.
    /// @return The final amount the user is going to receive.
    function _calculatePayoutAmount(
        WithdrawalRequest storage request,
        uint256 rsETHPrice,
        uint256 assetPrice
    )
        private
        view
        returns (uint256)
    {
        uint256 currentReturn = (request.rsETHUnstaked * rsETHPrice) / assetPrice;
        return (request.expectedAssetAmount < currentReturn) ? request.expectedAssetAmount : currentReturn;
    }

    function _createUnlockParams(
        ILRTOracle lrtOracle,
        ILRTUnstakingVault unstakingVault,
        address asset
    )
        internal
        view
        returns (UnlockParams memory)
    {
        return UnlockParams({
            rsETHPrice: lrtOracle.rsETHPrice(),
            assetPrice: lrtOracle.getAssetPrice(asset),
            totalAvailableAssets: unstakingVault.balanceOf(asset)
        });
    }

    function _validatePrices(
        uint256 rsETHPrice,
        uint256 assetPrice,
        uint256 minimumRsEthPrice,
        uint256 maximumRsEthPrice,
        uint256 minimumAssetPrice,
        uint256 maximumAssetPrice
    )
        internal
        pure
    {
        if (rsETHPrice < minimumRsEthPrice || rsETHPrice > maximumRsEthPrice) {
            revert RsETHPriceOutOfPriceRange(rsETHPrice);
        }
        if (assetPrice < minimumAssetPrice || assetPrice > maximumAssetPrice) {
            revert AssetPriceOutOfPriceRange(assetPrice);
        }
    }

    /// @dev Transfer assets (ETH or ERC20) to a recipient
    /// @param asset The asset address
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function _transferAsset(address asset, address to, uint256 amount) internal {
        if (asset == LRTConstants.ETH_TOKEN) {
            (bool sent,) = payable(to).call{ value: amount }("");
            if (!sent) revert EthTransferFailed();
        } else {
            IERC20(asset).safeTransfer(to, amount);
        }
    }

    /// @dev Get the balance of an asset (ETH or ERC20) held by this contract
    /// @param asset The asset address
    /// @return balance The asset balance of this contract
    function _getAssetBalance(address asset) internal view returns (uint256 balance) {
        return asset == LRTConstants.ETH_TOKEN ? address(this).balance : IERC20(asset).balanceOf(address(this));
    }

    /// @dev Deposit ETH to Aave v3
    /// @param amount The amount of ETH to deposit
    function _depositToAave(uint256 amount) internal {
        if (amount == 0) return;

        aaveWETHGateway.depositETH{ value: amount }(aavePool, address(this), 0);
        totalETHDepositedToAave += amount;

        emit ETHDepositedToAave(amount, totalETHDepositedToAave);
    }

    /// @dev Withdraw ETH from Aave v3
    /// @param amount The amount of ETH to withdraw
    function _withdrawFromAave(uint256 amount) internal returns (uint256 withdrawnAmount) {
        if (amount == 0) return 0;

        uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
        if (aaveBalance == 0) revert InsufficientAaveBalance();

        // Only withdraw up to the principal amount (don't use accrued interest for user withdrawals)
        uint256 withdrawablePrincipal = aaveBalance < totalETHDepositedToAave ? aaveBalance : totalETHDepositedToAave;

        withdrawnAmount = amount > withdrawablePrincipal ? withdrawablePrincipal : amount;
        if (withdrawnAmount == 0) return 0;

        aaveWETHGateway.withdrawETH(aavePool, withdrawnAmount, address(this));
        totalETHDepositedToAave -= withdrawnAmount;

        emit ETHWithdrawnFromAave(withdrawnAmount, totalETHDepositedToAave);
    }

    /// @dev Internal helper to check Aave health - returns false if unhealthy or disabled, doesn't revert
    /// @return healthy True if Aave integration is enabled and balance is healthy
    function _checkAaveHealth() internal view returns (bool healthy) {
        if (!isAaveIntegrationEnabled) return false;
        uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
        uint256 principal = totalETHDepositedToAave;
        // Allow small rounding differences (up to 2 wei)
        // Check if balance is significantly less than principal
        if (principal > aaveBalance && principal - aaveBalance > 2) return false;
        return true;
    }

    /// @dev Revoke approval for old aWETH token to Aave WETH Gateway
    function _revokeApprovalToAaveWETHGateway() internal {
        if (address(aaveAWETH) != address(0) && address(aaveWETHGateway) != address(0)) {
            IERC20(address(aaveAWETH)).forceApprove(address(aaveWETHGateway), 0);
        }
    }

    /// @dev Internal function to collect accrued interest from Aave to treasury
    /// @dev Does not perform health checks - caller must verify Aave health before calling
    /// @return interestAmount The amount of interest collected
    function _collectInterestToTreasury() internal returns (uint256 interestAmount) {
        uint256 aaveBalance = aaveAWETH.balanceOf(address(this));
        uint256 principal = totalETHDepositedToAave;

        // Return 0 if no interest or balance is less than principal (accounting for rounding)
        if (aaveBalance <= principal) return 0;

        interestAmount = aaveBalance - principal;

        aaveWETHGateway.withdrawETH(aavePool, interestAmount, address(this));

        address treasury = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
        (bool sent,) = payable(treasury).call{ value: interestAmount }("");
        if (!sent) revert TreasuryTransferFailed();

        emit InterestCollectedToTreasury(interestAmount, treasury);
    }
}
