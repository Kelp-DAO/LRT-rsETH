// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IL2ERC20Bridge } from "contracts/external/lido/IL2ERC20Bridge.sol";
import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title LidoBridge
 * @notice This contract is a wrapper for the Lido canonical bridge contract on Base
 */
contract LidoBridge is IL2TokenBridge {
    using SafeERC20 for IERC20;

    /// @notice Address of the wstETH token
    IERC20 public immutable wstETH;

    /// @notice Address of the Lido canonical bridge contract
    IL2ERC20Bridge public immutable lidoBridge;

    /// @notice Custom errors
    error NoMsgValueNeeded();
    error ZeroAmount();

    /**
     * @notice Event emitted when wstETH is bridged to L1
     * @param recipient The address of the recipient on L1
     * @param amount The amount of wstETH bridged
     */
    event WstETHBridged(address indexed recipient, uint256 amount);

    /**
     * @notice Constructor for the LidoBridge contract
     * @param _wstETH Address of the wstETH token
     * @param _lidoBridge Address of the Lido canonical bridge contract
     */
    constructor(address _wstETH, address _lidoBridge) {
        UtilLib.checkNonZeroAddress(_wstETH);
        UtilLib.checkNonZeroAddress(_lidoBridge);

        wstETH = IERC20(_wstETH);
        lidoBridge = IL2ERC20Bridge(_lidoBridge);
    }

    /**
     * @notice Bridges wstETH to L1
     * @dev No additional msg.value is needed for the fees, hence we reject it to
     *      avoid having stuck ETH in the contract
     * @param recipient The address of the recipient on L1
     * @param amount The amount of wstETH to bridge
     */
    function bridgeTokenToL1(address recipient, uint256 amount) external payable {
        UtilLib.checkNonZeroAddress(recipient);

        if (amount == 0) {
            revert ZeroAmount();
        }

        // No additional msg.value is needed for the fees
        if (msg.value != 0) {
            revert NoMsgValueNeeded();
        }

        // Transfer the token to this contract
        wstETH.safeTransferFrom(msg.sender, address(this), amount);

        // Approve the Lido bridge to transfer the token on behalf of this contract
        wstETH.safeIncreaseAllowance(address(lidoBridge), amount);

        // Bridge wstETH to the L1 recipient
        lidoBridge.withdrawTo(address(wstETH), recipient, amount, 0, bytes(""));

        emit WstETHBridged(recipient, amount);
    }
}
