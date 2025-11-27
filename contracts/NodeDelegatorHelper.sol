// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

// protocol libraries, interfaces, contracts
import { LRTConstants } from "./utils/LRTConstants.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";

import { IEigenPod } from "./external/eigenlayer/interfaces/IEigenPod.sol";
import { IStrategyManager } from "./external/eigenlayer/interfaces/IStrategyManager.sol";

import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { IDelegationManager } from "./external/eigenlayer/interfaces/IDelegationManager.sol";
import { IEigenPodManager } from "./external/eigenlayer/interfaces/IEigenPodManager.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { SlashingLib } from "./external/eigenlayer/libraries/SlashingLib.sol";

library NodeDelegatorHelper {
    using SlashingLib for uint256;
    using SlashingLib for uint64;
    using LRTConstants for ILRTConfig;

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function getDelegationManager(ILRTConfig lrtConfig) internal view returns (IDelegationManager) {
        return IDelegationManager(lrtConfig.getContract(LRTConstants.EIGEN_DELEGATION_MANAGER));
    }

    function getEigenPodManager(ILRTConfig lrtConfig) internal view returns (IEigenPodManager) {
        return IEigenPodManager(lrtConfig.getContract(LRTConstants.EIGEN_POD_MANAGER));
    }

    function getAssetBalance(ILRTConfig lrtConfig, address asset) internal view returns (uint256) {
        address strategy = lrtConfig.assetStrategy(asset);
        if (strategy == address(0)) {
            return 0;
        }
        uint256 withdrawableShare = getWithdrawableShare(lrtConfig, IStrategy(strategy));

        return IStrategy(strategy).sharesToUnderlyingView(withdrawableShare);
    }

    function getWithdrawableShares(
        ILRTConfig lrtConfig,
        IStrategy[] memory strategies
    )
        internal
        view
        returns (uint256[] memory withdrawableShares)
    {
        (withdrawableShares,) = getDelegationManager(lrtConfig).getWithdrawableShares(address(this), strategies);
    }

    function getWithdrawableShare(
        ILRTConfig lrtConfig,
        IStrategy strategy
    )
        internal
        view
        returns (uint256 withdrawableShare)
    {
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = strategy;

        uint256[] memory withdrawableShares = getWithdrawableShares(lrtConfig, strategies);
        return withdrawableShares[0];
    }

    function isSupportedStrategy(ILRTConfig lrtConfig, IStrategy strategy) internal view returns (bool) {
        if (lrtConfig.beaconChainETHStrategy() == address(strategy)) {
            return true;
        }

        return lrtConfig.isSupportedAsset(address(strategy.underlyingToken()));
    }

    function _getUnstakingVault(ILRTConfig lrtConfig) internal view returns (ILRTUnstakingVault) {
        return ILRTUnstakingVault(lrtConfig.unstakingVault());
    }

    function _getDelegationManager(ILRTConfig lrtConfig) internal view returns (IDelegationManager) {
        return IDelegationManager(lrtConfig.delegationManager());
    }

    function _getEigenPodManager(ILRTConfig lrtConfig) internal view returns (IEigenPodManager) {
        return IEigenPodManager(lrtConfig.eigenPodManager());
    }

    function _getNonce(ILRTConfig lrtConfig) internal view returns (uint256) {
        return _getDelegationManager(lrtConfig).cumulativeWithdrawalsQueued(address(this));
    }
}
