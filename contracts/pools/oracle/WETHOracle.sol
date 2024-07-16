// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @title WETHOracle Contract
/// @notice contract that returns 1e18 as the exchange rate of WETH/ETH
contract WETHOracle {
    function getRate() external pure returns (uint256) {
        return 1e18;
    }

    function rate() external pure returns (uint256) {
        return 1e18;
    }
}
