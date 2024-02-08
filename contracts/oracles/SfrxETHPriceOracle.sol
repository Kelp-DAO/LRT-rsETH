// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "../utils/UtilLib.sol";
import { IPriceFetcher } from "../interfaces/IPriceFetcher.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ISfrxETH {
    /// @notice How much frxETH is 1E18 sfrxETH worth. Price is in ETH, not USD
    function pricePerShare() external view returns (uint256);
}

/// @title sfrxETHPriceOracle Contract
/// @notice contract that fetches the exchange rate of sfrxETH/ETH
contract SfrxETHPriceOracle is IPriceFetcher, Initializable {
    address public sfrxETHContractAddress;

    error InvalidAsset();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param sfrxETHContractAddress_ sfrxETH address
    function initialize(address sfrxETHContractAddress_) external initializer {
        UtilLib.checkNonZeroAddress(sfrxETHContractAddress_);
        sfrxETHContractAddress = sfrxETHContractAddress_;
    }

    /// @notice Fetches Asset/ETH exchange rate
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) external view returns (uint256) {
        if (asset != sfrxETHContractAddress) {
            revert InvalidAsset();
        }

        return ISfrxETH(sfrxETHContractAddress).pricePerShare();
    }
}
