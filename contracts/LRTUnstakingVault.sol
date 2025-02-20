// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { INodeDelegator, IDelegationManager } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { ILRTWithdrawalManager } from "./interfaces/ILRTWithdrawalManager.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { IEigenStrategyManager } from "./external/eigenlayer/interfaces/IEigenStrategyManager.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LRTUnstakingVault Contract
/// @notice The contract that handles the unstaking of assets
contract LRTUnstakingVault is
    ILRTUnstakingVault,
    LRTConfigRoleChecker,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // Mapping from asset addresses to the total number of shares currently undergoing the unstaking process in
    // EigenLayer. This count is critical for accurately calculating the price of assets.
    mapping(address asset => uint256) public sharesUnstaking;

    mapping(bytes32 => bool) public trackedWithdrawal;

    modifier onlyLRTNodeDelegator() {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));

        if (lrtDepositPool.isNodeDelegator(msg.sender) != 1) {
            revert CallerNotLRTNodeDelegator();
        }
        _;
    }

    modifier onlyLRTWithdrawalManager() {
        if (msg.sender != lrtConfig.getContract(LRTConstants.LRT_WITHDRAW_MANAGER)) {
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

    /// @notice Adds shares that are in unstaking process.
    /// @param asset The asset address.
    /// @param amount The amount of shares added to the unstaking pool.
    /// @dev This function is only callable by the NodeDelegator contracts when it initiates unstaking process.
    function addSharesUnstaking(address asset, uint256 amount) external onlyLRTNodeDelegator {
        // Increase the tracking of shares currently in the process of unstaking from Eigenlayer.
        sharesUnstaking[asset] += amount;
    }

    /// @notice Adds shares that are in unstaking process.
    /// @param asset The asset address.
    /// @param amount The amount of shares added to the unstaking pool.
    /// @dev This function is only callable by the NodeDelegator contracts when it initiates unstaking process.
    function reduceSharesUnstaking(address asset, uint256 amount) external onlyLRTNodeDelegator {
        // Increase the tracking of shares currently in the process of unstaking from Eigenlayer.
        sharesUnstaking[asset] -= amount;
    }

    /// @notice Tracks the withdrawal initiated by the NodeDelegator contract.
    /// @param withdrawalRoot The withdrawal root.
    /// @dev This function is only callable by the NodeDelegator contracts when it initiates unstaking process.
    function trackWithdrawal(bytes32 withdrawalRoot) external onlyLRTNodeDelegator {
        trackedWithdrawal[withdrawalRoot] = true;
    }

    /// @notice transfers asset lying in this LRTUnstakingVault to node delegator contract
    /// @dev only callable by LRT Operator
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
        onlyLRTOperator
        onlySupportedAsset(asset)
    {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        address[] memory nodeDelegatorQueue = lrtDepositPool.getNodeDelegatorQueue();
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        IERC20(asset).safeTransfer(nodeDelegator, amount);
    }

    /// @notice transfers ETH lying in this LRTUnstakingVault to node delegator contract
    /// @dev only callable by LRT Operator
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param amount ETH amount to transfer
    function transferETHToNodeDelegator(uint256 ndcIndex, uint256 amount) external nonReentrant onlyLRTOperator {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        address[] memory nodeDelegatorQueue = lrtDepositPool.getNodeDelegatorQueue();
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        INodeDelegator(nodeDelegator).sendETHFromUnstakingVaultToNDC{ value: amount }();
        emit EthTransferred(nodeDelegator, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total asset amount in unstaking process.
    /// @param asset The asset address.
    /// @return The total asset amount in unstaking process.
    function getAssetsUnstaking(address asset) external view onlySupportedAsset(asset) returns (uint256) {
        if (asset == LRTConstants.ETH_TOKEN) {
            return sharesUnstaking[asset];
        }

        IStrategy strategy = IStrategy(lrtConfig.assetStrategy(asset));
        return strategy.sharesToUnderlyingView(sharesUnstaking[asset]);
    }

    /// @notice Returns the the vaults balance of the asset.
    /// @param asset The asset address.
    /// @return The balance of the asset.
    function balanceOf(address asset) external view returns (uint256) {
        if (asset == LRTConstants.ETH_TOKEN) {
            return address(this).balance;
        } else {
            return IERC20(asset).balanceOf(address(this));
        }
    }

    /// @notice Fetches balance of all assets staked in eigen layer through this contract
    /// @param user the user address
    /// @return assets the assets that the node delegator has deposited into strategies
    /// @return assetBalances the balances of the assets that the node delegator has deposited into strategies
    function getStakedAssetBalances(address user)
        external
        view
        override
        returns (address[] memory assets, uint256[] memory assetBalances)
    {
        (IStrategy[] memory strategies,) =
            IEigenStrategyManager(lrtConfig.getContract(LRTConstants.EIGEN_STRATEGY_MANAGER)).getDeposits(user);

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

    /**
     * @notice  Tracks the undelegated shares caused by ELOperatorDelegator undelegating
     * @dev     This function is only callable by the LRT Operator
     * @dev     This function will be called by operator when OperatorDelegator undelegated
     * @param   withdrawals  Withdrawals struct list needs to be tracked
     */
    function registerPendingWithdrawals(IDelegationManager.Withdrawal[] calldata withdrawals)
        external
        nonReentrant
        onlyLRTOperator
    {
        address elDelegationManagerAddr = lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER);
        IDelegationManager elDelegationManager = IDelegationManager(elDelegationManagerAddr);
        address beaconChainETHStrategy = lrtConfig.getContract(LRTConstants.BEACON_CHAIN_ETH_STRATEGY);
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));

        for (uint256 i = 0; i < withdrawals.length;) {
            IDelegationManager.Withdrawal memory withdrawal = withdrawals[i];
            bytes32 withdrawalRoot = elDelegationManager.calculateWithdrawalRoot(withdrawal);

            if (trackedWithdrawal[withdrawalRoot]) {
                revert WithdrawalAlreadyRegistered();
            }
            if (lrtDepositPool.isNodeDelegator(withdrawal.staker) != 1) {
                revert IncorrectStaker();
            }

            if (!elDelegationManager.pendingWithdrawals(withdrawalRoot)) {
                revert WithdrawalNotPending();
            }
            trackedWithdrawal[withdrawalRoot] = true;
            INodeDelegator(withdrawal.staker).increaseLastNonce();
            for (uint256 j = 0; j < withdrawal.strategies.length;) {
                if (beaconChainETHStrategy == address(withdrawal.strategies[j])) {
                    sharesUnstaking[LRTConstants.ETH_TOKEN] += withdrawal.shares[j];
                } else {
                    sharesUnstaking[address(withdrawal.strategies[j].underlyingToken())] += withdrawal.shares[j];
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
