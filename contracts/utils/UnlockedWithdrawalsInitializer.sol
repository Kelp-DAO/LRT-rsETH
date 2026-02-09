// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ILRTWithdrawalManager } from "../interfaces/ILRTWithdrawalManager.sol";
import { ILRTConfig } from "../interfaces/ILRTConfig.sol";
import { LRTConstants } from "./LRTConstants.sol";
import { LRTConfigRoleChecker } from "./LRTConfigRoleChecker.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @dev Extends the interface with view accessors and initialize2
interface ILRTWithdrawalManagerView is ILRTWithdrawalManager {
    function initialize2(
        uint256 unlockedWithdrawalsCountETHx,
        uint256 unlockedWithdrawalsCountSTETH,
        uint256 unlockedWithdrawalsCountETH
    )
        external;

    function isInitialized2() external view returns (bool);

    function nextLockedNonce(address asset) external view returns (uint256);

    function getRequestId(address asset, uint256 requestIndex) external pure returns (bytes32);

    function withdrawalRequests(bytes32 requestId)
        external
        view
        returns (uint256 rsETHUnstaked, uint256 expectedAssetAmount, uint256 withdrawalStartBlock);
}

/// @title UnlockedWithdrawalsInitializer
/// @notice Utility contract for counting and initializing unlocked withdrawals
contract UnlockedWithdrawalsInitializer is LRTConfigRoleChecker, Initializable {
    error AlreadyInitialized();
    error PendingWithdrawalsExist();
    error WithdrawalManagerAlreadyInitialized2();
    error UnsupportedAsset();
    error ZeroIterations();
    error ZeroConfig();

    mapping(address asset => uint256) public processedIndex; // next index to process
    mapping(address asset => uint256) public unlockedCount; // accumulated count

    event ChunkProcessed(address indexed asset, uint256 fromIndex, uint256 toIndexExclusive, uint256 added);
    event Finalized(uint256 countETHx, uint256 countSTETH, uint256 countETH);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        if (lrtConfigAddr == address(0)) revert ZeroConfig();

        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    modifier onlyBeforeInitialize2() {
        try _withdrawalManager().isInitialized2() returns (bool isInitialized) {
            if (isInitialized) revert WithdrawalManagerAlreadyInitialized2();
        } catch {
            revert WithdrawalManagerAlreadyInitialized2();
        }
        _;
    }

    /// @notice Processes up to maxIterations withdrawal requests for the given asset, counting unlocked withdrawals.
    /// @param asset The asset address to process (must be ETHx, stETH, or ETH)
    /// @param maxIterations Maximum number of withdrawal requests to process in this call
    /// @return processed Number of withdrawal requests processed in this call
    /// @return added Number of unlocked withdrawals found and added to the count
    function processChunk(
        address asset,
        uint256 maxIterations
    )
        external
        onlyLRTOperator
        onlyBeforeInitialize2
        returns (uint256 processed, uint256 added)
    {
        address steth = _stETH();
        address ethx = _ethX();
        address eth = _eth();
        if (asset != steth && asset != ethx && asset != eth) revert UnsupportedAsset();
        if (maxIterations == 0) revert ZeroIterations();

        uint256 start = processedIndex[asset];
        uint256 endExclusive = _withdrawalManager().nextLockedNonce(asset);
        if (start >= endExclusive) return (0, 0);

        uint256 limit = start + maxIterations;
        if (limit > endExclusive) limit = endExclusive;

        for (uint256 i = start; i < limit; i++) {
            bytes32 requestId = _withdrawalManager().getRequestId(asset, i);
            (, uint256 expectedAssetAmount,) = _withdrawalManager().withdrawalRequests(requestId);
            if (expectedAssetAmount > 0) {
                added++;
            }
        }
        unlockedCount[asset] += added;
        processed = limit - start;
        processedIndex[asset] = limit;
    }

    /// @notice Finalizes the initialization process by calling initialize2 on the Withdrawal Manager.
    /// @dev This function can only be called after all assets have been fully processed (isAssetComplete returns true).
    ///      It sets the unlocked withdrawal counts on the LRTWithdrawalManager.
    function finalizeInitialize2() external onlyLRTManager onlyBeforeInitialize2 {
        if (!isAssetComplete(_ethX()) || !isAssetComplete(_stETH()) || !isAssetComplete(_eth())) {
            revert PendingWithdrawalsExist();
        }

        uint256 countETHx = unlockedCount[_ethX()];
        uint256 countSTETH = unlockedCount[_stETH()];
        uint256 countETH = unlockedCount[_eth()];

        _withdrawalManager().initialize2(countETHx, countSTETH, countETH);
        emit Finalized(countETHx, countSTETH, countETH);
    }

    /// @notice Returns the total number of unlocked withdrawals for a specific asset
    /// @param asset The asset address
    /// @return unlockedWithdrawalsCount The total number of unlocked withdrawals for the asset
    function getUnlockedWithdrawalsCount(address asset) public view returns (uint256 unlockedWithdrawalsCount) {
        uint256 nextLockedNonce = _withdrawalManager().nextLockedNonce(asset);
        for (uint256 i = 0; i < nextLockedNonce; i++) {
            bytes32 requestId = _withdrawalManager().getRequestId(asset, i);
            (, uint256 expectedAssetAmount,) = _withdrawalManager().withdrawalRequests(requestId);
            if (expectedAssetAmount > 0) {
                unlockedWithdrawalsCount++;
            }
        }
    }

    /// @notice Checks whether all withdrawal requests for an asset have been processed
    /// @dev Compares the processed index with the current nextLockedNonce from the withdrawal manager
    /// @param asset The asset address to check
    /// @return true if all withdrawal requests for the asset have been processed, false otherwise
    function isAssetComplete(address asset) public view returns (bool) {
        uint256 target = _withdrawalManager().nextLockedNonce(asset);
        return processedIndex[asset] >= target;
    }

    function _withdrawalManager() internal view returns (ILRTWithdrawalManagerView) {
        return ILRTWithdrawalManagerView(lrtConfig.getContract(LRTConstants.LRT_WITHDRAW_MANAGER));
    }

    function _stETH() internal view returns (address) {
        return lrtConfig.getLSTToken(LRTConstants.ST_ETH_TOKEN);
    }

    function _ethX() internal view returns (address) {
        return lrtConfig.getLSTToken(LRTConstants.ETHX_TOKEN);
    }

    function _eth() internal pure returns (address) {
        return LRTConstants.ETH_TOKEN;
    }
}
