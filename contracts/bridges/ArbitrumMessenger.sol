// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { IArbitrumMessenger } from "contracts/interfaces/L2/IArbitrumMessenger.sol";

/**
 * @title ArbitrumMessenger
 * @notice Helper contract for bridging ETH from Arbitrum L2 to Ethereum Mainnet using the standard IL2Messenger
 * interface
 */
contract ArbitrumMessenger is IL2Messenger, ReentrancyGuard {
    /**
     * @notice Bridge ETH from Arbitrum L2 to Ethereum Mainnet
     * @param l2bridge The address of the L2 bridge on Arbitrum
     * @param target The address of the target contract on L1
     * @param value The amount of ETH to send
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable nonReentrant {
        if (msg.value != value) revert MismatchedMsgValue();
        IArbitrumMessenger(l2bridge).withdrawEth{ value: value }(target);
    }
}
