// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IArbitrumMessenger
 * @notice Interface for the Arbitrum's native bridge
 */
interface IArbitrumMessenger {
    /**
     * @notice Initiates a withdrawal of ETH to the specified recipient on L1
     * @param destination The address of the recipient on L1
     */
    function withdrawEth(address destination) external payable;
}
