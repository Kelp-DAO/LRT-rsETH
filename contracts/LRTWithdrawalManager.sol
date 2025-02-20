// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

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
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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

    // Maps each asset to user addresses, pointing to an ordert list of their withdrawal request nonces.
    // Utilizes a double-ended queue for efficient management and removal of initial requests.
    mapping(address asset => mapping(address user => DoubleEndedQueue.Uint256Deque requestNonces)) public
        userAssociatedNonces;

    // Asset amount commited to be withdrawn by users.
    mapping(address asset => uint256 amount) public assetsCommitted;

    modifier onlySupportedStrategy(address asset) {
        if (asset != LRTConstants.ETH_TOKEN && lrtConfig.assetStrategy(asset) == address(0)) {
            revert StrategyNotSupported();
        }
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
        if (rsETHUnstaked == 0 || rsETHUnstaked < minRsEthAmountToWithdraw[asset]) revert InvalidAmountToWithdraw();

        IERC20(lrtConfig.rsETH()).safeTransferFrom(msg.sender, address(this), rsETHUnstaked);

        uint256 expectedAssetAmount = getExpectedAssetAmount(asset, rsETHUnstaked);

        // Ensure the withdrawal does not exceed the available shares.
        if (expectedAssetAmount > getAvailableAssetAmount(asset)) revert ExceedAmountToWithdraw();

        // preventing over-withdrawal.
        assetsCommitted[asset] += expectedAssetAmount;

        _addUserWithdrawalRequest(asset, rsETHUnstaked, expectedAssetAmount);

        emit ReferralIdEmitted(referralId);
    }

    /// @notice Completes a user's withdrawal process by transferring the ETH/LST amount corresponding to the rsETH
    /// unstaked.
    /// @param asset The asset address the user wishes to withdraw.
    function completeWithdrawal(
        address asset,
        string calldata referralId
    )
        external
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
    {
        // Retrieve and remove the oldest withdrawal request for the user.
        uint256 usersFirstWithdrawalRequestNonce = userAssociatedNonces[asset][msg.sender].popFront();
        // Ensure the request is already unlocked.
        if (usersFirstWithdrawalRequestNonce >= nextLockedNonce[asset]) revert WithdrawalLocked();

        bytes32 requestId = getRequestId(asset, usersFirstWithdrawalRequestNonce);
        WithdrawalRequest memory request = withdrawalRequests[requestId];

        delete withdrawalRequests[requestId];

        // Check that the withdrawal delay has passed since the request's initiation.
        if (block.number < request.withdrawalStartBlock + withdrawalDelayBlocks) revert WithdrawalDelayNotPassed();

        if (asset == LRTConstants.ETH_TOKEN) {
            (bool sent,) = payable(msg.sender).call{ value: request.expectedAssetAmount }("");
            if (!sent) revert EthTransferFailed();
        } else {
            IERC20(asset).safeTransfer(msg.sender, request.expectedAssetAmount);
        }

        emit ReferralIdEmitted(referralId);
        emit AssetWithdrawalFinalized(msg.sender, asset, request.rsETHUnstaked, request.expectedAssetAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        operational functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Unlocks assets in the queue up to a specified limit.
    /// @param asset The address of the asset to unlock.
    /// @param firstExcludedIndex First withdrawal requests index that will not be considered for unlocking.
    /// @param minimumAssetPrice The minimum acceptable price for the asset.
    /// @param minimumRsEthPrice The minimum acceptable price for rsETH.
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
        onlyLRTOperator
        returns (uint256 rsETHBurned, uint256 assetAmountUnlocked)
    {
        ILRTOracle lrtOracle = ILRTOracle(lrtConfig.getContract(LRTConstants.LRT_ORACLE));
        ILRTUnstakingVault unstakingVault = ILRTUnstakingVault(lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT));

        UnlockParams memory params = _createUnlockParams(lrtOracle, unstakingVault, asset, firstExcludedIndex);

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

        emit AssetUnlocked(asset, rsETHBurned, assetAmountUnlocked, params.rsETHPrice, params.assetPrice);
    }

    /*//////////////////////////////////////////////////////////////
                            setters
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
        // Set an upper limit of no more than 10 days
        if (withdrawalDelayBlocks_ > 10 days / 12 seconds) revert ExceedWithdrawalDelay();

        withdrawalDelayBlocks = withdrawalDelayBlocks_;
        emit WithdrawalDelayBlocksUpdated(withdrawalDelayBlocks);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyRole(LRTConstants.PAUSER_ROLE) {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
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

    /*//////////////////////////////////////////////////////////////
                        internal functions
    //////////////////////////////////////////////////////////////*/

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
            rsETHUnstaked: rsETHUnstaked,
            expectedAssetAmount: expectedAssetAmount,
            withdrawalStartBlock: block.number
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

            // Calculate the amount user will recieve
            uint256 payoutAmount = _calculatePayoutAmount(request, rsETHPrice, assetPrice);

            if (availableAssetAmount < payoutAmount) break; // Exit if not enough assets to cover this request

            assetsCommitted[asset] -= request.expectedAssetAmount;
            // Set the amount the user will recieve
            request.expectedAssetAmount = payoutAmount;
            rsETHAmountToBurn += request.rsETHUnstaked;
            availableAssetAmount -= payoutAmount;
            assetAmountToUnlock += payoutAmount;
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
        address asset,
        uint256 firstExcludedIndex
    )
        internal
        view
        returns (UnlockParams memory)
    {
        return UnlockParams({
            rsETHPrice: lrtOracle.rsETHPrice(),
            assetPrice: lrtOracle.getAssetPrice(asset),
            totalAvailableAssets: unstakingVault.balanceOf(asset),
            firstExcludedIndex: firstExcludedIndex
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
}
