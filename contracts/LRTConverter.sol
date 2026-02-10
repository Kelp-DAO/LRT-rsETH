// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { LRTConstants } from "./utils/LRTConstants.sol";

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { ILRTConverter } from "./interfaces/ILRTConverter.sol";
import { ILRTWithdrawalManager } from "./interfaces/ILRTWithdrawalManager.sol";

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UnstakeStETH } from "./unstaking-adapters/UnstakeStETH.sol";

/// @dev Legacy unstaking adapters for swETH are kept for upgrade compatibility
import { UnstakeSwETH } from "./unstaking-adapters/UnstakeSwETH.sol";

/// @title LRTConverter - Unstakes LSTs to ETH and swaps ETH to LSTs
/// @notice This contract is responsible for unstaking LSTs to ETH and swapping ETH to LSTs
contract LRTConverter is
    ILRTConverter,
    LRTConfigRoleChecker,
    ReentrancyGuardUpgradeable,
    UnstakeSwETH,
    UnstakeStETH,
    IERC721Receiver
{
    using SafeERC20 for IERC20;

    mapping(bytes32 => bool) public _legacyProcessedWithdrawalRoots;
    mapping(address => bool) public _legacyConvertibleAssets;
    mapping(address => uint256) public _legacyConversionLimit;

    // needs to be added to total assets in protocol
    uint256 public ethValueInWithdrawal;

    mapping(address => bool) private whitelistedUsers;

    uint256 public whitelistedUnstakeAllowance;

    modifier onlyWhitelistedUser() {
        if (!isUserWhitelisted(msg.sender)) {
            revert UserNotWhitelisted();
        }
        _;
    }

    /// @dev Modifier to enforce unstaking limits and update counters
    /// @param amountToUnstake Amount of stETH to unstake
    modifier withinUnstakeLimits(uint256 amountToUnstake) {
        if (amountToUnstake == 0) {
            revert InvalidAmount();
        }

        uint256 availableActiveETHWithdrawals = _getActiveETHUserWithdrawals();

        if (amountToUnstake > whitelistedUnstakeAllowance + availableActiveETHWithdrawals) {
            revert UnstakeLimitExceeded();
        }

        // Consume intended withdrawal limit
        if (whitelistedUnstakeAllowance > 0) {
            uint256 whitelistedAmountConsumed =
                amountToUnstake > whitelistedUnstakeAllowance ? whitelistedUnstakeAllowance : amountToUnstake;

            whitelistedUnstakeAllowance -= whitelistedAmountConsumed;
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __ReentrancyGuard_init();
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /// @dev Initializes the contract
    /// @param _withdrawalQueueAddress Address of withdrawal queue (stETH)
    /// @param _stETHAddress Address of stETH
    /// @param _swEXITAddress Address of swEXIT (swETH)
    /// @param _swETHAddress Address of swETH
    function initialize2(
        address _withdrawalQueueAddress,
        address _stETHAddress,
        address _swEXITAddress,
        address _swETHAddress
    )
        external
        reinitializer(2)
        onlyLRTAdmin
    {
        __ReentrancyGuard_init();
        __initializeSwETH(_swEXITAddress, _swETHAddress);
        __initializeStETH(_withdrawalQueueAddress, _stETHAddress);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @dev fallback to receive funds
    receive() external payable { }

    /*////////////////////////////////////////////////////////////
                        write interactions
    //////////////////////////////////////////////////////////////*/

    /// @notice send asset from deposit pool to LRTConverter
    /// @dev Only callable by Asset Transfer Role and asset needs to be approved
    /// @param _asset Asset address to send
    /// @param _amount Asset amount to send
    function transferAssetFromDepositPool(
        address _asset,
        uint256 _amount
    )
        external
        onlySupportedERC20Token(_asset)
        onlyAssetTransferRole
    {
        address lrtDepositPoolAddress = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);

        ethValueInWithdrawal += (_amount * lrtOracle.getAssetPrice(_asset)) / 1e18;

        IERC20(_asset).safeTransferFrom(lrtDepositPoolAddress, address(this), _amount);
    }

    /// @notice send asset from LRTConverter to deposit pool
    /// @dev Only callable by Asset Transfer Role and asset needs to be approved
    /// @param _asset Asset address to send
    /// @param _amount Asset amount to send
    function transferAssetToDepositPool(
        address _asset,
        uint256 _amount
    )
        external
        onlySupportedERC20Token(_asset)
        onlyAssetTransferRole
    {
        address lrtDepositPoolAddress = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);
        uint256 assetValue = (_amount * lrtOracle.getAssetPrice(_asset)) / 1e18;

        // Set to 0 if assetValue exceeds ethValueInWithdrawal, otherwise subtract assetValue
        ethValueInWithdrawal = ethValueInWithdrawal > assetValue ? ethValueInWithdrawal - assetValue : 0;

        IERC20(_asset).safeTransfer(lrtDepositPoolAddress, _amount);
    }

    /// @notice raises a unstake request for steth on lido
    /// @param amountToUnstake Amount of stETH to unstake
    function unstakeStEth(uint256 amountToUnstake)
        external
        nonReentrant
        onlyLRTOperator
        withinUnstakeLimits(amountToUnstake)
    {
        _unstakeStEth(amountToUnstake);
    }

    /// @notice claim eth from lido for steth and sends to deposit pool
    function claimStEth(uint256 _requestId, uint256 _hint) external nonReentrant onlyLRTOperator {
        _claimStEth(_requestId, _hint);
        _sendEthToDepositPool(address(this).balance);
    }

    /// @notice raises a unstake request for sweth on swell
    function unstakeSwEth(uint256 amountToUnstake) external nonReentrant onlyLRTOperator {
        _unstakeSwEth(amountToUnstake);
    }

    /// @notice claim eth from sweth from swell for sweth and sends to deposit pool
    function claimSwEth(uint256 _tokenId) external nonReentrant onlyLRTOperator {
        _claimSwEth(_tokenId);
        _sendEthToDepositPool(address(this).balance);
    }

    /// @notice Add or remove a user from the whitelist
    /// @param user User address
    /// @param whitelisted Whether to whitelist or remove from whitelist
    function setUserWhitelisted(address user, bool whitelisted) external onlyLRTManager {
        whitelistedUsers[user] = whitelisted;
        emit UserWhitelisted(user, whitelisted);
    }

    /// @notice Batch add or remove users from the whitelist
    /// @param users Array of user addresses
    /// @param whitelisted Whether to whitelist or remove from whitelist
    function batchSetUserWhitelisted(address[] calldata users, bool whitelisted) external onlyLRTManager {
        for (uint256 i = 0; i < users.length; i++) {
            whitelistedUsers[users[i]] = whitelisted;
            emit UserWhitelisted(users[i], whitelisted);
        }
    }

    /// @notice Declare withdrawal intent (only whitelisted users)
    /// @param amount Amount of stETH to declare for withdrawal
    function declareWithdrawalIntent(uint256 amount) external nonReentrant onlyWhitelistedUser {
        if (amount == 0) {
            revert InvalidAmount();
        }
        uint256 maxWhitelistedAllowance = 1_000_000_000 ether;
        if (whitelistedUnstakeAllowance + amount > maxWhitelistedAllowance) {
            revert WhitelistedAllowanceExceeded();
        }

        whitelistedUnstakeAllowance = whitelistedUnstakeAllowance + amount;
        emit WithdrawalIntentDeclared(msg.sender, amount);
    }

    /*////////////////////////////////////////////////////////////
                        view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current unstaking limits and usage
    /// @return whitelistedAllowance Current whitelisted unstake allowance
    /// @return activeETHWithdrawals Current active ETH withdrawals
    function getUnstakeLimits() external view returns (uint256 whitelistedAllowance, uint256 activeETHWithdrawals) {
        whitelistedAllowance = whitelistedUnstakeAllowance;
        activeETHWithdrawals = _getActiveETHUserWithdrawals();
    }

    /// @notice Check if a user is whitelisted
    /// @param user User address to check
    /// @return True if user is whitelisted
    function isUserWhitelisted(address user) public view returns (bool) {
        return whitelistedUsers[user];
    }

    /*////////////////////////////////////////////////////////////
                        internal functions
    //////////////////////////////////////////////////////////////*/

    function _sendEthToDepositPool(uint256 _amount) internal {
        address lrtDepositPoolAddress = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);

        if (ethValueInWithdrawal > _amount) {
            ethValueInWithdrawal -= _amount;
        } else {
            ethValueInWithdrawal = 0;
        }
        // Send eth to deposit pool
        ILRTDepositPool(lrtDepositPoolAddress).receiveFromLRTConverter{ value: _amount }();
        emit EthTransferred(lrtDepositPoolAddress, _amount);
    }

    /// @dev Get active user ETH withdrawals from LRTWithdrawalManager
    function _getActiveETHUserWithdrawals() internal view returns (uint256 activeETHWithdrawals) {
        ILRTWithdrawalManager lrtWithdrawalManager =
            ILRTWithdrawalManager(lrtConfig.getContract(LRTConstants.LRT_WITHDRAW_MANAGER));
        activeETHWithdrawals = lrtWithdrawalManager.assetsCommitted(LRTConstants.ETH_TOKEN);
    }
}
