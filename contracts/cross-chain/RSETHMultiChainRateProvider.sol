// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { MultiChainRateProvider } from "./MultiChainRateProvider.sol";

import { ILRTOracle } from "../interfaces/ILRTOracle.sol";

/// @title rsETH multi chain rate provider
/// @notice Provides the current exchange rate of rsETH to various receiver contract on a different chains
contract RSETHMultiChainRateProvider is MultiChainRateProvider {
    address public rsETHPriceOracle;

    constructor(address _rsETHPriceOracle, address _layerZeroEndpoint) {
        rsETHPriceOracle = _rsETHPriceOracle;

        rateInfo = RateInfo({
            tokenSymbol: "rsETH",
            tokenAddress: 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7, // rsETH token address on ETH mainnet
            baseTokenSymbol: "ETH",
            baseTokenAddress: address(0) // Address 0 for native tokens
         });

        layerZeroEndpoint = _layerZeroEndpoint;
    }

    /// @notice Returns the latest rate from the rsETH contract
    function getLatestRate() public view override returns (uint256) {
        return ILRTOracle(rsETHPriceOracle).rsETHPrice();
    }

    /// @notice Calls the getLatestRate function and returns the rate
    function getRate() external view returns (uint256) {
        return getLatestRate();
    }
}
