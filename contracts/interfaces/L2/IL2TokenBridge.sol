// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IL2TokenBridge
 * @notice Interface for the L2 to L1 ERC20 token bridge
 * @dev Each token should have its corresponding L2 token bridge
 */
interface IL2TokenBridge {
    /**
     * @notice Initiates a withdrawal of a specified amount of tokens to the specified recipient on L1
     * @param recipient The address of the recipient on L1
     * @param amount The amount of tokens to bridge to L1
     */
    function bridgeTokenToL1(address recipient, uint256 amount) external payable;
}
