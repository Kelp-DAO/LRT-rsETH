// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ILRTOracle } from "contracts/interfaces/ILRTOracle.sol";
import { MultiChainRateProvider } from "contracts/cross-chain/MultiChainRateProvider.sol";

/// @title rsETH multi chain rate provider
/// @notice Provides the current exchange rate of rsETH to various receiver contract on the different chains
contract RSETHMultiChainRateProvider is MultiChainRateProvider {
    address public immutable rsETHPriceOracle;

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
