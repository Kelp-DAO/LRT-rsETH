// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { IScrollMessenger } from "contracts/interfaces/L2/IScrollMessenger.sol";

contract ScrollMessenger is IL2Messenger {
    /**
     * @notice Bridge ETH from Scroll L2 to Ethereum Mainnet
     * @param l2bridge The address of the L2 bridge on Scroll
     * @param target The address of the target contract on L1
     * @param value The amount of ETH to send
     * @dev Gas limit is set to 0 to use the default gas limit
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable {
        IScrollMessenger(l2bridge).sendMessage{ value: value }(target, value, "", 0, msg.sender);
    }
}
