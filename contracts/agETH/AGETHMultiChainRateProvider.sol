// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { MultiChainRateProvider } from "contracts/cross-chain/MultiChainRateProvider.sol";

interface IAgEthRateProvider {
    function getRate() external view returns (uint256);
}

/// @title agETH multi chain rate provider
/// @notice Provides the current exchange rate of agETH to various receiver contract on the different chains
contract AGETHMultiChainRateProvider is MultiChainRateProvider {
    address public immutable agETHPriceOracle;

    constructor(address _agETHPriceOracle, address _layerZeroEndpoint) {
        agETHPriceOracle = _agETHPriceOracle;

        rateInfo = RateInfo({
            tokenSymbol: "agETH",
            tokenAddress: 0xe1B4d34E8754600962Cd944B535180Bd758E6c2e, // agETH token address on ETH mainnet
            baseTokenSymbol: "ETH",
            baseTokenAddress: address(0) // Address 0 for native tokens
        });

        layerZeroEndpoint = _layerZeroEndpoint;
    }

    /// @notice Returns the latest rate from the agETH rate provider contract
    function getLatestRate() public view override returns (uint256) {
        return IAgEthRateProvider(agETHPriceOracle).getRate();
    }

    /// @notice Calls the getLatestRate function and returns the rate
    function getRate() external view returns (uint256) {
        return getLatestRate();
    }
}
