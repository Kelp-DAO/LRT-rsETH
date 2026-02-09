// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title Recoverable
 * @notice A contract that allows the admin to recover tokens and ETH sent to it by mistake.
 */
abstract contract Recoverable is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Custom errors
    error ZeroAmount();
    error TransferFailed();
    error InsufficientBalance();

    /// @notice Events
    event TokensRecovered(address indexed token, address indexed recipient, uint256 amount);
    event ETHRecovered(address indexed recipient, uint256 amount);

    /*
     * @notice Initializes the contract with the admin address
     * @param admin The address of the admin who will have the DEFAULT_ADMIN_ROLE
     */
    constructor(address admin) {
        UtilLib.checkNonZeroAddress(admin);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Allows the admin to recover any tokens sent to this contract by mistake
     * @param tokenAddress The address of the token to recover
     * @param recipient The recipient of the recovered tokens
     * @param amount The amount to recover
     */
    function recoverTokens(
        address tokenAddress,
        address recipient,
        uint256 amount
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UtilLib.checkNonZeroAddress(tokenAddress);
        UtilLib.checkNonZeroAddress(recipient);
        if (amount == 0) revert ZeroAmount();
        if (IERC20(tokenAddress).balanceOf(address(this)) < amount) revert InsufficientBalance();

        IERC20(tokenAddress).safeTransfer(recipient, amount);

        emit TokensRecovered(tokenAddress, recipient, amount);
    }

    /**
     * @notice Allows the admin to recover any ETH sent to this contract
     * @param recipient The recipient of the recovered ETH
     * @param amount The amount to recover
     */
    function recoverETH(address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(recipient);
        if (amount == 0) revert ZeroAmount();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success,) = payable(recipient).call{ value: amount }("");
        if (!success) revert TransferFailed();

        emit ETHRecovered(recipient, amount);
    }

    /// @dev Handles direct ETH transfers; useful for recovering ETH sent directly to this contract
    receive() external payable { }
}
