// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";
import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { ILRTWithdrawalManager } from "./interfaces/ILRTWithdrawalManager.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { IStrategyManager } from "./external/eigenlayer/interfaces/IStrategyManager.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IDelegationManager } from "./external/eigenlayer/interfaces/IDelegationManager.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SlashingLib } from "./external/eigenlayer/libraries/SlashingLib.sol";

/// @title LRTUnstakingVault Contract
/// @notice The contract that handles the unstaking of assets
contract LRTUnstakingVault is
    ILRTUnstakingVault,
    LRTConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using SlashingLib for *;
    using LRTConstants for ILRTConfig;

    mapping(address asset => uint256) private __deprecated_sharesUnstaking;

    mapping(bytes32 => bool) public trackedWithdrawal;

    uint256 public uncompletedWithdrawalCount;
    uint256 public maxUncompletedWithdrawalCount;

    // Portion of the vault reserved for servicing queued withdrawals; unavailable for instant withdrawals.
    mapping(address asset => uint256 buffer) public queuedWithdrawalsBuffer;

    modifier onlyLRTNodeDelegator() {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));

        if (lrtDepositPool.isNodeDelegator(msg.sender) != 1) {
            revert CallerNotLRTNodeDelegator();
        }
        _;
    }

    modifier onlyLRTWithdrawalManager() {
        if (msg.sender != lrtConfig.withdrawManager()) {
            revert CallerNotLRTWithdrawalManager();
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

    /*//////////////////////////////////////////////////////////////
                        receive functions
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }

    /// @dev receive from LRTDepositPool
    function receiveFromLRTDepositPool() external payable { }

    /// @dev receive from NodeDelegator
    function receiveFromNodeDelegator() external payable { }

    /*//////////////////////////////////////////////////////////////
                        write functions
    //////////////////////////////////////////////////////////////*/

    /// @notice This is used by withdrawal manager when unlocking assets. The unlocked assets are pulled from the vault
    /// and used to pay the user.
    /// @param asset The asset address.
    /// @param amount The amount of asset to redeem.
    function redeem(address asset, uint256 amount) external nonReentrant onlyLRTWithdrawalManager {
        if (asset == LRTConstants.ETH_TOKEN) {
            ILRTWithdrawalManager(msg.sender).receiveFromLRTUnstakingVault{ value: amount }();
        } else {
            IERC20(asset).safeTransfer(msg.sender, amount);
        }
    }

    /// @notice transfers asset lying in this LRTUnstakingVault to node delegator contract
    /// @dev only callable by Asset Transfer Role
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param asset Asset address
    /// @param amount Asset amount to transfer
    function transferAssetToNodeDelegator(
        uint256 ndcIndex,
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        onlyAssetTransferRole
        onlySupportedAsset(asset)
    {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.depositPool());
        address[] memory nodeDelegatorQueue = lrtDepositPool.getNodeDelegatorQueue();
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        IERC20(asset).safeTransfer(nodeDelegator, amount);
    }

    /// @notice transfers ETH lying in this LRTUnstakingVault to node delegator contract
    /// @dev only callable by Asset Transfer Role
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param amount ETH amount to transfer
    function transferETHToNodeDelegator(
        uint256 ndcIndex,
        uint256 amount
    )
        external
        nonReentrant
        onlyAssetTransferRole
        onlySupportedAsset(LRTConstants.ETH_TOKEN)
    {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.depositPool());
        address[] memory nodeDelegatorQueue = lrtDepositPool.getNodeDelegatorQueue();
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        INodeDelegator(nodeDelegator).sendETHFromUnstakingVaultToNDC{ value: amount }();
        emit EthTransferred(nodeDelegator, amount);
    }

    /// @notice Set the max number of uncompleted withdrawals.
    /// @param _maxUncompletedWithdrawalCount The max number of uncompleted withdrawals.
    function setMaxUncompletedWithdrawalCount(uint256 _maxUncompletedWithdrawalCount) external onlyLRTManager {
        // 120 is the max number of uncompleted withdrawals that allows us to still perform update rsETH price
        // Need buffer for theoretical operator forced undelegations (ndc count * asset count = 15)
        if (_maxUncompletedWithdrawalCount > 80) {
            revert MaxUncompletedWithdrawalCountTooHigh();
        }
        maxUncompletedWithdrawalCount = _maxUncompletedWithdrawalCount;

        emit MaxUncompletedWithdrawalCountSet(_maxUncompletedWithdrawalCount);
    }

    /// @notice Set the uncompleted withdrawal count.
    /// @notice Can be used on forced undelegations.
    /// @dev only callable by LRT Manager
    function setUncompletedWithdrawalCount() external onlyLRTManager {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        IDelegationManager delegationManager =
            IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
        address[] memory nodeDelegatorQueue = lrtDepositPool.getNodeDelegatorQueue();
        uint256 totalQueued;
        for (uint256 i = 0; i < nodeDelegatorQueue.length; i++) {
            address nodeDelegator = nodeDelegatorQueue[i];
            (IDelegationManager.Withdrawal[] memory queuedWithdrawals,) =
                delegationManager.getQueuedWithdrawals(nodeDelegator);
            totalQueued += queuedWithdrawals.length;
        }

        uncompletedWithdrawalCount = totalQueued;

        emit UncompletedWithdrawalCountSet(totalQueued);
    }

    /// @notice Increase the number of uncompleted withdrawals.
    /// @dev This function is only callable by the NodeDelegator contracts during the unstaking process.
    function increaseUncompletedWithdrawalCount() external onlyLRTNodeDelegator {
        uncompletedWithdrawalCount++;
    }

    /// @notice Decrease the number of uncompleted withdrawals.
    /// @dev This function is only callable by the NodeDelegator contracts during the unstaking process.
    function decreaseUncompletedWithdrawalCount() external onlyLRTNodeDelegator {
        if (uncompletedWithdrawalCount > 0) {
            uncompletedWithdrawalCount--;
        }
    }

    /// @notice Set the reserved buffer for queued withdrawals for an asset.
    /// @param asset The asset address.
    /// @param buffer The reserved amount for queued withdrawals.
    function setQueuedWithdrawalsBuffer(
        address asset,
        uint256 buffer
    )
        external
        onlyLRTOperator
        onlySupportedAsset(asset)
    {
        queuedWithdrawalsBuffer[asset] = buffer;
        emit QueuedWithdrawalsBufferUpdated(asset, buffer);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the the vaults balance of the asset.
    /// @param asset The asset address.
    /// @return The balance of the asset.
    function balanceOf(address asset) public view returns (uint256) {
        if (asset == LRTConstants.ETH_TOKEN) {
            return address(this).balance;
        } else {
            return IERC20(asset).balanceOf(address(this));
        }
    }

    /// @notice Returns the amount of the asset available for instant withdrawal.
    /// @param asset The asset address.
    /// @return availableAmount The amount of the asset available for instant withdrawal.
    function getAssetsAvailableForInstantWithdrawal(address asset)
        external
        view
        onlySupportedAsset(asset)
        returns (uint256 availableAmount)
    {
        uint256 vaultBalance = balanceOf(asset);
        uint256 reservedBuffer = queuedWithdrawalsBuffer[asset];
        availableAmount = reservedBuffer >= vaultBalance ? 0 : vaultBalance - reservedBuffer;
    }

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @param staker the staker address
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getStakedAssetBalances(address staker)
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        (IStrategy[] memory strategies,) = IStrategyManager(lrtConfig.strategyManager()).getDeposits(staker);

        uint256 strategiesLength = strategies.length;
        assets = new address[](strategiesLength);
        assetBalances = new uint256[](strategiesLength);

        for (uint256 i = 0; i < strategiesLength;) {
            assets[i] = address(IStrategy(strategies[i]).underlyingToken());
            assetBalances[i] = IStrategy(strategies[i]).userUnderlyingView(staker);
            unchecked {
                ++i;
            }
        }
    }
}
