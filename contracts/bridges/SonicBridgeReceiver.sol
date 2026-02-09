// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IEthereumTokenDeposit } from "contracts/interfaces/L2/ISonicBridge.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/// @title SonicBridgeReceiver
/// @notice Contract deployed on ETH mainnet to handle Sonic bridge withdrawals
/// @dev This contract must have the same address as SonicChainNativeTokenBridge on Sonic chain
/// @dev Only the contract itself can claim withdrawals due to Sonic gateway design
contract SonicBridgeReceiver is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Ethereum Token Deposit contract address on ETH mainnet
    IEthereumTokenDeposit public immutable ETHEREUM_TOKEN_DEPOSIT;

    /// @notice L1Vault contract that should receive the claimed tokens
    address public l1Vault;

    /// @notice WETH token address on ETH mainnet
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Role for managing claims
    bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");

    /// @notice Mapping to track claimed withdrawals to prevent replay
    mapping(uint256 withdrawalId => bool claimed) public claimedWithdrawals;

    /// @notice Events
    event WithdrawalClaimed(uint256 indexed withdrawalId, address indexed token, uint256 amount);
    event TokensTransferredToVault(address indexed token, uint256 amount, address indexed vault);
    event L1VaultUpdated(address indexed oldVault, address indexed newVault);

    /// @notice Custom errors
    error InvalidWithdrawalId();
    error WithdrawalAlreadyClaimed();
    error ClaimFailed();
    error TransferToVaultFailed();
    error InvalidVault();
    error InsufficientBalance();

    /// @param _ethereumTokenDeposit Address of Ethereum Token Deposit contract
    /// @param _l1Vault Address of L1Vault contract to receive claimed tokens
    /// @param _admin Admin address for role management
    /// @param _claimer Address that can execute claims
    constructor(address _ethereumTokenDeposit, address _l1Vault, address _admin, address _claimer) {
        UtilLib.checkNonZeroAddress(_ethereumTokenDeposit);
        UtilLib.checkNonZeroAddress(_l1Vault);
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_claimer);

        ETHEREUM_TOKEN_DEPOSIT = IEthereumTokenDeposit(_ethereumTokenDeposit);
        l1Vault = _l1Vault;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CLAIMER_ROLE, _admin);
        _grantRole(CLAIMER_ROLE, _claimer);
    }

    /// @notice Claims a withdrawal from Sonic bridge and transfers to L1Vault
    /// @param withdrawalId The withdrawal ID from Sonic
    /// @param token The token address on ETH mainnet to claim
    /// @param amount The amount to claim
    /// @param proof The merkle proof for the withdrawal
    function claimAndTransferToVault(
        uint256 withdrawalId,
        address token,
        uint256 amount,
        bytes calldata proof
    )
        external
        nonReentrant
        onlyRole(CLAIMER_ROLE)
    {
        if (withdrawalId == 0) revert InvalidWithdrawalId();
        if (claimedWithdrawals[withdrawalId]) revert WithdrawalAlreadyClaimed();

        // Mark as claimed before external call to prevent reentrancy
        claimedWithdrawals[withdrawalId] = true;

        // Get balance before claim
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // Claim from Sonic bridge
        ETHEREUM_TOKEN_DEPOSIT.claim(withdrawalId, token, amount, proof);
        emit WithdrawalClaimed(withdrawalId, token, amount);

        // Verify we received the tokens and transfer to L1Vault
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 received = balanceAfter - balanceBefore;
        if (received == 0) revert InsufficientBalance();

        // Transfer tokens to L1Vault
        IERC20(token).safeTransfer(l1Vault, received);
        emit TokensTransferredToVault(token, received, l1Vault);
    }

    /// @notice Claims a withdrawal without automatic transfer (for manual handling)
    /// @param withdrawalId The withdrawal ID from Sonic
    /// @param token The token address on ETH mainnet
    /// @param amount The amount to claim
    /// @param proof The merkle proof for the withdrawal
    function claimWithdrawal(
        uint256 withdrawalId,
        address token,
        uint256 amount,
        bytes calldata proof
    )
        external
        nonReentrant
        onlyRole(CLAIMER_ROLE)
    {
        if (withdrawalId == 0) revert InvalidWithdrawalId();
        if (claimedWithdrawals[withdrawalId]) revert WithdrawalAlreadyClaimed();

        claimedWithdrawals[withdrawalId] = true;

        ETHEREUM_TOKEN_DEPOSIT.claim(withdrawalId, token, amount, proof);
        emit WithdrawalClaimed(withdrawalId, token, amount);
    }

    /// @notice Manually transfer tokens to L1Vault (for claimed but not transferred tokens)
    /// @param token The token address to transfer
    /// @param amount The amount to transfer (0 = transfer all)
    function transferToVault(address token, uint256 amount) external nonReentrant onlyRole(CLAIMER_ROLE) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 transferAmount = amount == 0 ? balance : amount;
        if (transferAmount > balance) revert InsufficientBalance();

        IERC20(token).safeTransfer(l1Vault, transferAmount);
        emit TokensTransferredToVault(token, transferAmount, l1Vault);
    }

    /// @notice Updates the L1Vault address
    /// @param _newVault The new L1Vault address
    function updateL1Vault(address _newVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_newVault);
        address oldVault = l1Vault;
        l1Vault = _newVault;
        emit L1VaultUpdated(oldVault, _newVault);
    }

    /// @notice Check if a withdrawal has been claimed
    /// @param withdrawalId The withdrawal ID to check
    /// @return True if claimed, false otherwise
    function isWithdrawalClaimed(uint256 withdrawalId) external view returns (bool) {
        return claimedWithdrawals[withdrawalId];
    }

    /// @notice Get contract balances for a token
    /// @param token The token address to check balance for
    /// @return The balance of the specified token
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice Emergency recovery function for admin
    /// @param token Token address to recover
    /// @param recipient Recipient address
    /// @param amount Amount to recover (0 = recover all)
    function emergencyRecover(address token, address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(recipient);

        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 recoverAmount = amount == 0 ? balance : amount;
        if (recoverAmount > balance) revert InsufficientBalance();

        IERC20(token).safeTransfer(recipient, recoverAmount);
    }
}
