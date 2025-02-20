// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IL2Messenger {
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable;
}
