// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { IScrollMessenger } from "contracts/interfaces/L2/IScrollMessenger.sol";

/**
 * @title ScrollMessenger
 * @notice Helper contract for bridging ETH from Scroll L2 to Ethereum Mainnet using the standard IL2Messenger interface
 */
contract ScrollMessenger is IL2Messenger, ReentrancyGuard {
    /**
     * @notice Bridge ETH from Scroll L2 to Ethereum Mainnet
     * @param l2bridge The address of the L2 bridge on Scroll
     * @param target The address of the target contract on L1
     * @param value The amount of ETH to send
     * @dev Gas limit is set to 0 to use the default gas limit
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable nonReentrant {
        if (msg.value != value) revert MismatchedMsgValue();
        IScrollMessenger(l2bridge).sendMessage{ value: value }(target, value, "", 0, msg.sender);
    }
}
