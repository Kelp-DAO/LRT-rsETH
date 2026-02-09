// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IL2Messenger
 * @notice Generic interface for bridging ETH from L2 to L1
 */
interface IL2Messenger {
    /// @notice Error thrown when the message value does not match the expected value
    error MismatchedMsgValue();

    /**
     * @notice Bridge ETH from L2 to L1 via a specified bridge contract
     * @param l2bridge The address of the L2 bridge contract
     * @param target The address of the recipient on L1
     * @param value The amount of ETH to send
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable;
}
