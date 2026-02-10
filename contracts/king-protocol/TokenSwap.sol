// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IKingProtocol } from "./IKingProtocol.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UtilLib } from "../utils/UtilLib.sol";
import { LRTConstants } from "../utils/LRTConstants.sol";

/// @title TokenSwap - Simple token swap contract for King Protocol
/// @notice Allows admins/managers to deposit accepted tokens to King Protocol and withdraw KING tokens
contract TokenSwap is AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice King Protocol contract interface
    IKingProtocol public kingProtocol;

    /// @notice KING token contract
    IERC20 public kingToken;

    /// @notice Mapping of supported tokens for swapping
    mapping(address acceptedToken => bool isAccepted) public supportedTokens;

    /// @notice Array to track all supported token addresses for enumeration
    address[] public supportedTokensList;

    /// @notice Emitted when tokens are deposited to King Protocol
    /// @param asset The asset deposited
    /// @param amount The amount deposited
    /// @param shareReceived The amount of share tokens received
    /// @param caller The address that initiated the deposit
    event TokensDeposited(address indexed asset, uint256 amount, uint256 shareReceived, address indexed caller);

    /// @notice Emitted when KING tokens are withdrawn
    /// @param recipient The address that received the KING tokens
    /// @param amount The amount of KING tokens withdrawn
    /// @param caller The address that initiated the withdrawal
    event KingWithdrawn(address indexed recipient, uint256 amount, address indexed caller);

    /// @notice Emitted when King Protocol address is updated
    /// @param oldProtocol The old King Protocol address
    /// @param newProtocol The new King Protocol address
    event KingProtocolUpdated(address indexed oldProtocol, address indexed newProtocol);

    /// @notice Emitted when token addresses are updated
    /// @param tokenType The type of token updated ("KING")
    /// @param oldToken The old token address
    /// @param newToken The new token address
    event TokenAddressUpdated(string indexed tokenType, address indexed oldToken, address indexed newToken);

    /// @notice Emitted when a token is added to supported tokens list
    /// @param token The token address added
    event SupportedTokenAdded(address indexed token);

    /// @notice Emitted when a token is removed from supported tokens list
    /// @param token The token address removed
    event SupportedTokenRemoved(address indexed token);

    /// @notice Emitted when contract is paused/unpaused
    /// @param paused The new pause state
    event PauseStateChanged(bool paused);

    error ZeroAmount();
    error UnsupportedAsset();
    error InsufficientBalance();
    error TokenAlreadySupported();
    error TokenNotSupported();
    error CannotRemoveLastToken();
    error ArrayLengthMismatch();

    modifier onlyAdmin() {
        if (!hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert("Caller is not admin");
        }
        _;
    }

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender)) {
            revert("Caller is not manager");
        }
        _;
    }

    modifier onlyAdminOrManager() {
        if (!hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert("Caller is not admin or manager");
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param admin The admin address
    /// @param manager The manager address
    /// @param _kingProtocol The King Protocol contract address
    /// @param _kingToken The KING token contract address
    /// @param initialSupportedTokens Array of initially supported token addresses
    function initialize(
        address admin,
        address manager,
        address _kingProtocol,
        address _kingToken,
        address[] memory initialSupportedTokens
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(admin);
        UtilLib.checkNonZeroAddress(manager);
        UtilLib.checkNonZeroAddress(_kingProtocol);
        UtilLib.checkNonZeroAddress(_kingToken);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(LRTConstants.DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, manager);

        kingProtocol = IKingProtocol(_kingProtocol);
        kingToken = IERC20(_kingToken);

        // Add initial supported tokens
        for (uint256 i = 0; i < initialSupportedTokens.length; i++) {
            _addSupportedToken(initialSupportedTokens[i]);
        }
    }

    /// @notice Deposit tokens to King Protocol
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @return shareReceived The amount of share tokens received (after fees)
    function depositToKingProtocol(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyAdminOrManager
        returns (uint256 shareReceived)
    {
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (!supportedTokens[asset]) {
            revert UnsupportedAsset();
        }

        IERC20 assetToken = IERC20(asset);
        uint256 contractBalance = assetToken.balanceOf(address(this));

        if (contractBalance < amount) {
            revert InsufficientBalance();
        }

        // Create arrays for the deposit call
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = asset;
        amounts[0] = amount;

        // Preview the deposit to get expected shares
        (uint256 expectedShares,) = kingProtocol.previewDeposit(tokens, amounts);
        shareReceived = expectedShares;

        // Approve King Protocol to spend the tokens
        assetToken.forceApprove(address(kingProtocol), amount);

        // Deposit to King Protocol
        kingProtocol.deposit(tokens, amounts, address(this));

        // Reset approval after successful deposit
        assetToken.forceApprove(address(kingProtocol), 0);

        emit TokensDeposited(asset, amount, shareReceived, msg.sender);
    }

    /// @notice Deposit multiple tokens to King Protocol in a single transaction
    /// @param assets Array of asset addresses to deposit
    /// @param amounts Array of amounts to deposit (must match assets length)
    /// @return shareReceived The total amount of share tokens received (after fees)
    function depositMultipleToKingProtocol(
        address[] memory assets,
        uint256[] memory amounts
    )
        external
        nonReentrant
        whenNotPaused
        onlyAdminOrManager
        returns (uint256 shareReceived)
    {
        _validateMultipleDepositInputs(assets, amounts);
        _validateAssetsAndBalances(assets, amounts);

        // Preview the deposit to get expected shares
        (uint256 expectedShares,) = kingProtocol.previewDeposit(assets, amounts);
        shareReceived = expectedShares;

        _approveTokensForDeposit(assets, amounts);
        kingProtocol.deposit(assets, amounts, address(this));
        _resetTokenApprovals(assets);
        _emitMultipleDepositEvents(assets, amounts);
    }

    /// @notice Internal function to validate multiple deposit inputs
    /// @param assets Array of asset addresses
    /// @param amounts Array of amounts
    function _validateMultipleDepositInputs(address[] memory assets, uint256[] memory amounts) internal pure {
        if (assets.length == 0) {
            revert ZeroAmount();
        }

        if (assets.length != amounts.length) {
            revert ArrayLengthMismatch();
        }
    }

    /// @notice Internal function to validate assets and balances
    /// @param assets Array of asset addresses
    /// @param amounts Array of amounts
    function _validateAssetsAndBalances(address[] memory assets, uint256[] memory amounts) internal view {
        for (uint256 i = 0; i < assets.length; i++) {
            if (amounts[i] == 0) {
                revert ZeroAmount();
            }

            if (!supportedTokens[assets[i]]) {
                revert UnsupportedAsset();
            }

            IERC20 assetToken = IERC20(assets[i]);
            uint256 contractBalance = assetToken.balanceOf(address(this));
            if (contractBalance < amounts[i]) {
                revert InsufficientBalance();
            }
        }
    }

    /// @notice Internal function to approve tokens for deposit
    /// @param assets Array of asset addresses
    /// @param amounts Array of amounts
    function _approveTokensForDeposit(address[] memory assets, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).forceApprove(address(kingProtocol), amounts[i]);
        }
    }

    /// @notice Internal function to reset token approvals
    /// @param assets Array of asset addresses
    function _resetTokenApprovals(address[] memory assets) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).forceApprove(address(kingProtocol), 0);
        }
    }

    /// @notice Internal function to emit deposit events
    /// @param assets Array of asset addresses
    /// @param amounts Array of amounts
    function _emitMultipleDepositEvents(address[] memory assets, uint256[] memory amounts) internal {
        for (uint256 i = 0; i < assets.length; i++) {
            emit TokensDeposited(assets[i], amounts[i], 0, msg.sender);
        }
    }

    /// @notice Withdraw KING tokens from the contract
    /// @param recipient The address to receive the KING tokens
    /// @param amount The amount of KING tokens to withdraw
    function withdrawKing(address recipient, uint256 amount) external nonReentrant whenNotPaused onlyAdminOrManager {
        if (amount == 0) {
            revert ZeroAmount();
        }

        UtilLib.checkNonZeroAddress(recipient);

        uint256 contractBalance = kingToken.balanceOf(address(this));
        if (contractBalance < amount) {
            revert InsufficientBalance();
        }

        kingToken.safeTransfer(recipient, amount);

        emit KingWithdrawn(recipient, amount, msg.sender);
    }

    /// @notice Get the expected share amount for a deposit
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @return shareAmount The expected share amount to receive (after fees)
    /// @return depositFee The deposit fee amount
    function getExpectedShareAmount(
        address asset,
        uint256 amount
    )
        external
        view
        returns (uint256 shareAmount, uint256 depositFee)
    {
        if (!supportedTokens[asset]) {
            revert UnsupportedAsset();
        }

        // Create arrays for the preview call
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = asset;
        amounts[0] = amount;

        return kingProtocol.previewDeposit(tokens, amounts);
    }

    /// @notice Get the expected share amount for multiple token deposits
    /// @param assets Array of asset addresses to deposit
    /// @param amounts Array of amounts to deposit (must match assets length)
    /// @return shareAmount The expected total share amount to receive (after fees)
    /// @return depositFee The total deposit fee amount
    function getExpectedShareAmountMultiple(
        address[] memory assets,
        uint256[] memory amounts
    )
        external
        view
        returns (uint256 shareAmount, uint256 depositFee)
    {
        if (assets.length == 0) {
            revert ZeroAmount();
        }

        if (assets.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        // Validate all assets are supported
        for (uint256 i = 0; i < assets.length; i++) {
            if (!supportedTokens[assets[i]]) {
                revert UnsupportedAsset();
            }
        }

        return kingProtocol.previewDeposit(assets, amounts);
    }

    /// @notice Get contract balances for supported tokens and KING token
    /// @return tokenBalances Array of balances for each supported token
    /// @return tokens Array of supported token addresses (corresponding to tokenBalances)
    /// @return kingBalance The KING token balance
    function getTokenBalances()
        external
        view
        returns (uint256[] memory tokenBalances, address[] memory tokens, uint256 kingBalance)
    {
        uint256 length = supportedTokensList.length;
        tokenBalances = new uint256[](length);
        tokens = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            tokens[i] = supportedTokensList[i];
            tokenBalances[i] = IERC20(supportedTokensList[i]).balanceOf(address(this));
        }

        kingBalance = kingToken.balanceOf(address(this));
    }

    /// @notice Get balance for a specific token
    /// @param token The token address to check balance for
    /// @return balance The token balance of this contract
    function getTokenBalance(address token) external view returns (uint256 balance) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice Check if an asset is supported for deposits
    /// @param asset The asset address to check
    /// @return supported True if asset is supported
    function isSupportedAsset(address asset) external view returns (bool supported) {
        return supportedTokens[asset];
    }

    /// @notice Get all supported token addresses
    /// @return tokens Array of all supported token addresses
    function getSupportedTokens() external view returns (address[] memory tokens) {
        return supportedTokensList;
    }

    /// @notice Pause the contract (admin only)
    function pause() external onlyManager {
        _pause();
        emit PauseStateChanged(true);
    }

    /// @notice Unpause the contract (admin only)
    function unpause() external onlyAdmin {
        _unpause();
        emit PauseStateChanged(false);
    }

    /// @notice Update the King Protocol contract address (admin only)
    /// @param _kingProtocol The new King Protocol contract address
    function setKingProtocol(address _kingProtocol) external onlyManager {
        UtilLib.checkNonZeroAddress(_kingProtocol);

        address oldProtocol = address(kingProtocol);
        kingProtocol = IKingProtocol(_kingProtocol);

        emit KingProtocolUpdated(oldProtocol, _kingProtocol);
    }

    /// @notice Update the KING token address (admin only)
    /// @param _kingToken The new KING token address
    function setKingToken(address _kingToken) external onlyManager {
        UtilLib.checkNonZeroAddress(_kingToken);

        address oldToken = address(kingToken);
        kingToken = IERC20(_kingToken);

        emit TokenAddressUpdated("KING", oldToken, _kingToken);
    }

    /// @notice Add a token to the supported tokens list (manager only)
    /// @param token The token address to add
    function addSupportedToken(address token) external onlyManager {
        _addSupportedToken(token);
    }

    /// @notice Remove a token from the supported tokens list (manager only)
    /// @param token The token address to remove
    function removeSupportedToken(address token) external onlyManager {
        if (!supportedTokens[token]) {
            revert TokenNotSupported();
        }

        if (supportedTokensList.length <= 1) {
            revert CannotRemoveLastToken();
        }

        _removeSupportedToken(token);
    }

    /// @notice Internal function to add a supported token
    /// @param token The token address to add
    function _addSupportedToken(address token) internal {
        UtilLib.checkNonZeroAddress(token);

        if (supportedTokens[token]) {
            revert TokenAlreadySupported();
        }

        supportedTokens[token] = true;
        supportedTokensList.push(token);

        emit SupportedTokenAdded(token);
    }

    /// @notice Internal function to remove a supported token
    /// @param token The token address to remove
    function _removeSupportedToken(address token) internal {
        supportedTokens[token] = false;

        // Find and remove from array
        for (uint256 i = 0; i < supportedTokensList.length; i++) {
            if (supportedTokensList[i] == token) {
                supportedTokensList[i] = supportedTokensList[supportedTokensList.length - 1];
                supportedTokensList.pop();
                break;
            }
        }

        emit SupportedTokenRemoved(token);
    }

    /// @notice Emergency function to withdraw any ERC20 token (admin only)
    /// @param token The token to withdraw
    /// @param recipient The recipient address
    /// @param amount The amount to withdraw
    function emergencyWithdraw(address token, address recipient, uint256 amount) external onlyAdmin {
        UtilLib.checkNonZeroAddress(token);
        UtilLib.checkNonZeroAddress(recipient);

        if (amount == 0) {
            revert ZeroAmount();
        }

        IERC20(token).safeTransfer(recipient, amount);
    }
}
