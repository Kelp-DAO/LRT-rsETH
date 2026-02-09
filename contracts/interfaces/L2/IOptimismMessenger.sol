// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IOptimismMessenger
 * @notice Interface for the Optimism's native bridge
 */
interface IOptimismMessenger {
    /**
     * @notice Initiates a withdrawal of ETH to the specified recipient on L1
     * @param _to The address of the recipient on L1
     * @param _minGasLimit The minimum gas limit for the withdrawal
     * @param _extraData Additional data to be sent with the withdrawal (for tracing or other purposes)
     */
    function bridgeETHTo(address _to, uint32 _minGasLimit, bytes memory _extraData) external payable;
}
