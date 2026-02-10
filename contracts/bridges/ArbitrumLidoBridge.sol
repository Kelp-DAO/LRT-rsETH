// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IArbitrumL2GatewayRouter } from "contracts/external/arbitrum/IArbitrumL2GatewayRouter.sol";
import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title ArbitrumLidoBridge
 * @notice This contract is the wrapper for the Arbitrum L2 Gateway Router used strictly for bridging wstETH to L1
 */
contract ArbitrumLidoBridge is IL2TokenBridge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Address of the wstETH token on L1
    IERC20 public immutable wstETHOnL1;

    /// @notice Address of the wstETH token on L2
    IERC20 public immutable wstETHOnArbitrum;

    /// @notice Address of the Arbitrum L2 Gateway Router
    IArbitrumL2GatewayRouter public immutable arbitrumL2GatewayRouter;

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
     * @notice Constructor for the ArbitrumLidoBridge contract
     * @param _wstETHOnL1 Address of the wstETH token on L1
     * @param _wstETHOnArbitrum Address of the wstETH token on Arbitrum
     * @param _arbitrumL2GatewayRouter Address of the Arbitrum L2 Gateway Router
     */
    constructor(address _wstETHOnL1, address _wstETHOnArbitrum, address _arbitrumL2GatewayRouter) {
        UtilLib.checkNonZeroAddress(_wstETHOnL1);
        UtilLib.checkNonZeroAddress(_wstETHOnArbitrum);
        UtilLib.checkNonZeroAddress(_arbitrumL2GatewayRouter);

        wstETHOnL1 = IERC20(_wstETHOnL1);
        wstETHOnArbitrum = IERC20(_wstETHOnArbitrum);
        arbitrumL2GatewayRouter = IArbitrumL2GatewayRouter(_arbitrumL2GatewayRouter);
    }

    /**
     * @notice Bridges wstETH from Arbitrum to L1
     * @dev No additional msg.value is needed for the fees, hence we reject it to
     *      avoid having stuck ETH in the contract
     * @param recipient The address of the recipient on L1
     * @param amount The amount of wstETH to bridge
     */
    function bridgeTokenToL1(address recipient, uint256 amount) external payable nonReentrant {
        UtilLib.checkNonZeroAddress(recipient);

        if (amount == 0) {
            revert ZeroAmount();
        }

        // No additional msg.value is needed for the fees
        if (msg.value != 0) {
            revert NoMsgValueNeeded();
        }

        // Transfer the tokens to this contract
        wstETHOnArbitrum.safeTransferFrom(msg.sender, address(this), amount);

        // Approve the Arbitrum L2 Gateway Router to transfer the tokens on behalf of this contract
        wstETHOnArbitrum.safeIncreaseAllowance(address(arbitrumL2GatewayRouter), amount);

        // Bridge wstETH to the L1 recipient
        arbitrumL2GatewayRouter.outboundTransfer(address(wstETHOnL1), recipient, amount, bytes(""));

        emit WstETHBridged(recipient, amount);
    }
}
