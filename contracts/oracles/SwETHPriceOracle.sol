// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ISwETH {
    function getRate() external view returns (uint256);
}

/// @title SwETHPriceOracle Contract
/// @notice contract that fetches the exchange rate of SwETH/ETH
contract SwETHPriceOracle is IPriceFetcher, Initializable {
    address public swETHAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param swETHAddress_ SwETH address
    function initialize(address swETHAddress_) external initializer {
        UtilLib.checkNonZeroAddress(swETHAddress_);
        swETHAddress = swETHAddress_;
    }

    /// @notice Fetches Asset/ETH exchange rate
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) external view returns (uint256) {
        if (asset != swETHAddress) {
            revert InvalidAsset();
        }

        return ISwETH(swETHAddress).getRate();
    }
}
