// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILRTOracle {
    // errors
    error AssetOracleNotSupported();
    error InvalidPriceOracle();
    error PriceAboveDailyThreshold();

    // events
    event AssetPriceOracleUpdate(address indexed asset, address indexed priceOracle);
    event RsETHPriceUpdate(uint256 newPrice, uint256 oldPrice);
    event PricePercentageLimitUpdate(uint256 newLimit);
    event FeeMinted(address treasury, uint256 rsethAmount);
    event RsETHPriceDecrease(uint256 highestRsethPrice, uint256 newCalculatedRsETHPrice);
    event PeriodInTimestampUpdate(uint256 newPeriod);

    // methods
    function getAssetPrice(address asset) external view returns (uint256);
    function assetPriceOracle(address asset) external view returns (address);
    function rsETHPrice() external view returns (uint256);
}
