// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { ILineaMessageService } from "contracts/interfaces/L2/ILineaMessageService.sol";

import { Recoverable } from "contracts/utils/Recoverable.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title LineaMessenger
 * @notice Helper contract for bridging ETH from Linea L2 to Ethereum Mainnet using the standard IL2Messenger
 * interface
 */
contract LineaMessenger is IL2Messenger, Recoverable {
    /// @notice Custom errors
    error InsufficientAmountForBridge();

    /// @notice Events
    event ETHSentViaLineaBridge(address indexed l2bridge, address indexed target, uint256 value, uint256 fee);

    /// @notice Constructor that initializes the contract with the admin address
    constructor(address _admin) Recoverable(_admin) { }

    /**
     * @notice Bridge ETH from Linea L2 to Ethereum Mainnet
     * @param l2bridge The address of the L2 bridge on Linea
     * @param target The address of the target contract on L1
     * @param value The amount of ETH to send
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable nonReentrant {
        UtilLib.checkNonZeroAddress(l2bridge);
        UtilLib.checkNonZeroAddress(target);

        if (value == 0) revert ZeroAmount();
        if (msg.value != value) revert MismatchedMsgValue(); // Ensure the sent value matches the expected value to
        // avoid trapping ETH in this contract

        uint256 minimumFee = ILineaMessageService(l2bridge).minimumFeeInWei();
        if (value <= minimumFee) revert InsufficientAmountForBridge(); // Ensure Linea native bridge fee can be covered
        // and there is some ETH actually bridged after deducting the fee

        ILineaMessageService(l2bridge).sendMessage{ value: value }(target, minimumFee, bytes(""));

        emit ETHSentViaLineaBridge(l2bridge, target, value, minimumFee);
    }
}
