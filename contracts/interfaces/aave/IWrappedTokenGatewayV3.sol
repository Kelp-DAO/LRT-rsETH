// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface IWrappedTokenGatewayV3 {
    function depositETH(address pool, address onBehalfOf, uint16 referralCode) external payable;

    function withdrawETH(address pool, uint256 amount, address to) external;
}
