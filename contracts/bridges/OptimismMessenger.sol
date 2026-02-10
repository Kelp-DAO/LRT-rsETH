// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { IOptimismMessenger } from "contracts/interfaces/L2/IOptimismMessenger.sol";

/**
 * @title OptimismMessenger
 * @notice Helper contract for bridging ETH from Optimism L2 (OP mainnet) to Ethereum Mainnet using the standard
 * IL2Messenger interface
 */
contract OptimismMessenger is IL2Messenger, ReentrancyGuard {
    /// @notice The recommended gas limit for sending ETH to L1 via the Optimism bridge
    uint32 public constant DEFAULT_GAS_LIMIT = 200_000;

    /**
     * @notice Bridge ETH from Optimism L2 to Ethereum Mainnet
     * @param l2bridge The address of the L2 bridge on Optimism
     * @param target The address of the target contract on L1
     * @param value The amount of ETH to send
     */
    function sendETHToL1ViaBridge(address l2bridge, address target, uint256 value) external payable nonReentrant {
        if (msg.value != value) revert MismatchedMsgValue();
        IOptimismMessenger(l2bridge).bridgeETHTo{ value: value }(target, DEFAULT_GAS_LIMIT, bytes(""));
    }
}
