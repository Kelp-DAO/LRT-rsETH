// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { IEigenDelegationManager } from "./external/eigenlayer/interfaces/IEigenDelegationManager.sol";
import { IEigenDelayedWithdrawalRouter } from "./external/eigenlayer/interfaces/IEigenDelayedWithdrawalRouter.sol";
import { ILRTWithdrawalManager } from "./interfaces/ILRTWithdrawalManager.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";

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
}
