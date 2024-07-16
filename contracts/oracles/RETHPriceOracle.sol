// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IrETH {
    function getExchangeRate() external view returns (uint256);
}

/// @title RETHPriceOracle Contract
/// @notice contract that fetches the exchange rate of RETH/ETH
contract RETHPriceOracle is IPriceFetcher, Initializable {
    address public rETHAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param rETHAddress_ RETH address
    function initialize(address rETHAddress_) external initializer {
        UtilLib.checkNonZeroAddress(rETHAddress_);
        rETHAddress = rETHAddress_;
    }

    /// @notice Fetches Asset/ETH exchange rate
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) external view returns (uint256) {
        if (asset != rETHAddress) {
            revert InvalidAsset();
        }

        return IrETH(rETHAddress).getExchangeRate();
    }
}
