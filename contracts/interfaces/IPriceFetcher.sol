// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface IPriceFetcher {
    function getAssetPrice(address asset) external view returns (uint256);
}
