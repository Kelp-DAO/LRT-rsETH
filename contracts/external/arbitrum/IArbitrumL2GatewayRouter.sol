// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IArbitrumL2GatewayRouter
 * @notice Interface for the Arbitrum L2 Gateway Router
 */
interface IArbitrumL2GatewayRouter {
    /**
     * @notice Initiates an outbound transfer of tokens from Arbitrum to L1
     * @param _l1Token The address of the token on L1
     * @param _to The address of the recipient on L1
     * @param _amount The amount of tokens to transfer
     * @param _data Additional data to include in the transfer
     * @return A bytes array containing the result of the transfer
     */
    function outboundTransfer(
        address _l1Token,
        address _to,
        uint256 _amount,
        bytes calldata _data
    )
        external
        payable
        returns (bytes memory);
}
