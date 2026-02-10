// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title ILineaMessageService
 * @notice Interface for the Linea's native bridge
 */
interface ILineaMessageService {
    /**
     * @notice Initiates a withdrawal of ETH to the specified recipient on L1
     * @param _to The address of the recipient on L1
     * @param _fee The fee to be paid for the message
     * @param _calldata The calldata to be sent with the message
     */
    function sendMessage(address _to, uint256 _fee, bytes memory _calldata) external payable;

    /**
     * @notice Returns the minimum fee required for sending a message
     * @dev This fee is charged to prevent spam and denial of service attacks
     * @return The minimum fee in wei
     */
    function minimumFeeInWei() external view returns (uint256);

    /**
     * @notice Returns the ETH bridging limit for the current period in wei
     * @dev This limit is used to control the amount of ETH that can be bridged in a given period
     * @return The limit in wei
     */
    function limitInWei() external view returns (uint256);

    /**
     * @notice Returns the amount of ETH that has already been bridged in the current period
     * @dev The difference between the `limitInWei()` and this amount gives the remaining amount that can be bridged for
     * the current period
     * @return The amount in wei
     */
    function currentPeriodAmountInWei() external view returns (uint256);
}
