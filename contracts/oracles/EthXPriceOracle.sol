// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IETHXStakePoolsManager {
    function getExchangeRate() external view returns (uint256);
    function staderConfig() external view returns (address);
}

interface IStaderConfig {
    function getETHxToken() external view returns (address);
}

/// @title EthXPriceOracle Contract
/// @notice contract that fetches the exchange rate of ETHX/ETH
contract EthXPriceOracle is IPriceFetcher, Initializable {
    /// @dev deprecated
    address public ethXStakePoolsManagerProxyAddress;
    address public ethxAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param ethXStakePoolsManagerProxyAddress_ ETHX address
    function initialize(address ethXStakePoolsManagerProxyAddress_) external initializer {
        UtilLib.checkNonZeroAddress(ethXStakePoolsManagerProxyAddress_);
        ethXStakePoolsManagerProxyAddress = ethXStakePoolsManagerProxyAddress_;
    }

    function initialize2() external reinitializer(2) {
        address staderConfigProxyAddress = IETHXStakePoolsManager(ethXStakePoolsManagerProxyAddress).staderConfig();
        ethxAddress = IStaderConfig(staderConfigProxyAddress).getETHxToken();
    }

    /// @notice Fetches Asset/ETH exchange rate
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) external view returns (uint256) {
        if (asset != ethxAddress) {
            revert InvalidAsset();
        }

        return IETHXStakePoolsManager(ethXStakePoolsManagerProxyAddress).getExchangeRate();
    }
}
