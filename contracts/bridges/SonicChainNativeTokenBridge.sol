// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";
import { ISonicBridge, ISonicTokenPairs } from "contracts/interfaces/L2/ISonicBridge.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/// @title SonicChainNativeTokenBridge
/// @notice Bridge contract for transferring tokens from Sonic to Ethereum using Sonic's native bridge
/// @dev This contract must have the same address as SonicBridgeReceiver on ETH mainnet
/// @dev Implements IL2TokenBridge interface for integration with RSETHPoolV3AutoBridgedTokens
contract SonicChainNativeTokenBridge is IL2TokenBridge, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The token that this bridge handles
    IERC20 public immutable token;

    /// @notice Sonic's Bridge contract address
    ISonicBridge public immutable sonicBridge;

    /// @notice Sonic's Token Pairs contract address
    ISonicTokenPairs public immutable tokenPairs;

    /// @notice The address of SonicBridgeReceiver on ETH mainnet (same as this contract's address)
    address public immutable bridgeReceiver;

    /// @notice Emitted when tokens are bridged to L1
    event TokensBridgedToL1(
        address indexed recipient, uint256 amount, uint96 indexed bridgeWithdrawalId, address indexed bridgeReceiver
    );

    /// @notice Custom errors
    error InvalidAmount();
    error InsufficientBalance();
    error TokenNotSupported();
    error BridgeFailed();
    error InvalidBridgeReceiver();
    error NoMsgValueNeeded();

    /// @dev Constructor to set the immutable addresses
    /// @param _token The asset token address that this bridge will handle
    /// @param _sonicBridge The Sonic Bridge contract address
    /// @param _tokenPairs The Sonic Token Pairs contract address
    /// @param _admin The admin address
    constructor(address _token, address _sonicBridge, address _tokenPairs, address _admin) {
        UtilLib.checkNonZeroAddress(_token);
        UtilLib.checkNonZeroAddress(_sonicBridge);
        UtilLib.checkNonZeroAddress(_tokenPairs);
        UtilLib.checkNonZeroAddress(_admin);

        token = IERC20(_token);
        sonicBridge = ISonicBridge(_sonicBridge);
        tokenPairs = ISonicTokenPairs(_tokenPairs);
        bridgeReceiver = address(this);

        // Check if token is supported by getting the original token mapping
        address originalToken = tokenPairs.mintedToOriginal(_token);
        if (originalToken == address(0)) {
            revert TokenNotSupported();
        }

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /// @notice Initiates a withdrawal of a specified amount of tokens to the L1Vault via SonicBridgeReceiver
    /// @dev The recipient parameter is ignored as Sonic gateway only allows contract self-claiming
    /// @dev The actual recipient will be determined by SonicBridgeReceiver which forwards to L1Vault
    /// @param recipient The intended final recipient (informational only - actual recipient is L1Vault)
    /// @param amount The amount of tokens to bridge to L1
    function bridgeTokenToL1(address recipient, uint256 amount) external payable override nonReentrant {
        UtilLib.checkNonZeroAddress(recipient);

        // recipient parameter is kept for IL2TokenBridge interface compatibility
        // but the actual flow will be: SonicBridge -> SonicBridgeReceiver -> L1Vault
        if (amount == 0) revert InvalidAmount();

        // No additional msg.value is needed for the fees
        if (msg.value != 0) revert NoMsgValueNeeded();

        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 balance = token.balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        // Get the original token address (validated in constructor)
        address originalToken = tokenPairs.mintedToOriginal(address(token));

        // Generate a unique UID for this transaction
        uint96 uid = uint96(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp, block.number, msg.sender, recipient, amount, tx.gasprice, bridgeReceiver
                    )
                )
            ) % type(uint96).max
        );

        // Ensure UID is not zero
        if (uid == 0) {
            uid = uint96(uint256(keccak256(abi.encodePacked(block.number, msg.sender, tx.gasprice, bridgeReceiver))));
        }

        // Store the current token balance before withdrawal
        uint256 balanceBefore = token.balanceOf(address(this));

        // Approve the Sonic bridge to spend the tokens
        token.safeIncreaseAllowance(address(sonicBridge), amount);

        // Initiate withdrawal on Sonic bridge
        // Note: Sonic gateway will only allow SonicBridgeReceiver to claim (same address as this contract)
        sonicBridge.withdraw(uid, originalToken, amount);

        // Verify tokens were transferred/burned
        uint256 balanceAfter = token.balanceOf(address(this));
        if (balanceBefore - balanceAfter != amount) {
            revert BridgeFailed();
        }

        emit TokensBridgedToL1(recipient, amount, uid, bridgeReceiver);
    }

    /// @notice Gets the original token address for the bridged token
    /// @return The original token address on Ethereum
    function getOriginalToken() external view returns (address) {
        return tokenPairs.mintedToOriginal(address(token));
    }

    /// @notice Checks if the token is supported for bridging
    /// @return True if the token is supported, false otherwise
    function isTokenSupported() external view returns (bool) {
        return tokenPairs.mintedToOriginal(address(token)) != address(0);
    }

    /// @notice Gets the balance of tokens held by this bridge
    /// @return The token balance
    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Gets the Sonic bridge contract address
    /// @return The address of the Sonic bridge contract
    function getBridgeAddress() external view returns (address) {
        return address(sonicBridge);
    }

    /// @notice Gets the token pairs contract address
    /// @return The address of the token pairs contract
    function getTokenPairsAddress() external view returns (address) {
        return address(tokenPairs);
    }

    /// @notice Allows the admin to recover any tokens sent to this contract by mistake
    /// @param tokenAddress The address of the token to recover
    /// @param recipient The recipient of the recovered tokens
    /// @param amount The amount to recover
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
        if (amount == 0) revert InvalidAmount();

        IERC20(tokenAddress).safeTransfer(recipient, amount);
    }

    /// @notice Allows the admin to recover any ETH sent to this contract
    /// @param recipient The recipient of the recovered ETH
    /// @param amount The amount to recover
    function recoverETH(address recipient, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(recipient);
        if (amount == 0) revert InvalidAmount();
        if (address(this).balance < amount) revert InsufficientBalance();

        (bool success,) = payable(recipient).call{ value: amount }("");
        if (!success) revert BridgeFailed();
    }
}
