// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function getConfiguration(address asset) external view returns (uint256);
}
