// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTOracle {
    // events
    event AssetPriceOracleUpdate(address indexed asset, address indexed priceOracle);

    // methods
    function getAssetPrice(address asset) external view returns (uint256);
    function assetPriceOracle(address asset) external view returns (address);
    function rsETHPrice() external view returns (uint256);
}
