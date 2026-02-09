// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConfigRoleChecker, ILRTConfig, LRTConstants } from "./utils/LRTConfigRoleChecker.sol";

import { ERC20Upgradeable, Initializable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title rsETH token Contract
/// @author Kelp DAO
/// @notice The ERC20 contract for the rsETH token
contract RSETH is Initializable, LRTConfigRoleChecker, ERC20Upgradeable, PausableUpgradeable {
    /*//////////////////////////////////////////////////////////////
                            State Variables
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum amount that can be minted in a 24-hour period
    uint256 public maxMintAmountPerDay;

    /// @notice Amount minted in the current 24-hour period
    uint256 public currentPeriodMintedAmount;

    /// @notice Start time of the current 24-hour period
    uint256 public periodStartTime;

    /// @notice Address to which recovered funds are sent
    address public custodyAddress;

    /// @dev If > 0, transfers TO or FROM this address are blocked until timestamp (24h block)
    mapping(address account => uint256 blockedUntil) public transfersBlockedUntil;

    /// @dev Permanently exempt addresses mapping (rsETH transfers for these can never be blocked)
    mapping(address account => bool isExempt) public isPermanentlyExempt;

    /*//////////////////////////////////////////////////////////////
                            Modifiers
    //////////////////////////////////////////////////////////////*/

    /// @dev Modifier to check and update daily mint limits
    /// @param amount The amount to be minted
    modifier checkDailyMintLimit(uint256 amount) {
        // Check if we need to reset the period if it has been more than 24 hours
        if (block.timestamp >= periodStartTime + 1 days) {
            currentPeriodMintedAmount = 0;
            periodStartTime = getCurrentPeriodStartTime();
        }

        // Check if minting would exceed the daily limit
        if (currentPeriodMintedAmount + amount > maxMintAmountPerDay) {
            revert DailyMintLimitExceeded(currentPeriodMintedAmount + amount, maxMintAmountPerDay);
        }

        currentPeriodMintedAmount += amount;
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            Custom Errors
    //////////////////////////////////////////////////////////////*/

    error PeriodStartTimeShouldBeWithin24Hours();
    error DailyMintLimitExceeded(uint256 currentAmount, uint256 maxAmount);
    error TransfersBlocked(address account, uint256 blockedUntil);
    error CannotPermanentlyExemptBlockedAddress(address account, uint256 blockedUntil);
    error AddressPermanentlyExempt(address account);
    error NoActiveTransferBlock(address account);

    /*//////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    event MaxMintAmountPerDayUpdated(uint256 newMaxMintAmountPerDay);
    event FrozenFundsRecovered(address indexed from, address indexed to, uint256 amount);
    event UserTransfersBlocked(address indexed user, uint256 until);
    event PermanentExemptionAdded(address indexed account);
    event CustodyAddressUpdated(address indexed newCustodyAddress);
    event PeriodStartTimeSet(uint256 newPeriodStartTime);

    /*//////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                            Initializers
    //////////////////////////////////////////////////////////////*/

    /// @dev Initializes the contract
    /// @param admin Admin address
    /// @param lrtConfigAddr LRT config address
    function initialize(address admin, address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(admin);
        UtilLib.checkNonZeroAddress(lrtConfigAddr);

        __ERC20_init("rsETH", "rsETH");
        __Pausable_init();
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /// @notice Initializes the contract with a period start time and the custody address
    /// @param _periodStartTime The period start time
    /// @param _custodyAddress The custody address for recovered funds
    function reinitialize(uint256 _periodStartTime, address _custodyAddress) external reinitializer(2) onlyLRTManager {
        if (_periodStartTime > block.timestamp || _periodStartTime <= block.timestamp - 1 days) {
            revert PeriodStartTimeShouldBeWithin24Hours();
        }
        periodStartTime = _periodStartTime;
        emit PeriodStartTimeSet(_periodStartTime);

        _setCustodyAddress(_custodyAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            Manager Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the maximum amount that can be minted in 24 hours
    /// @param _maxMintAmountPerDay The maximum amount that can be minted in 24 hours
    function setMaxMintAmountPerDay(uint256 _maxMintAmountPerDay) external onlyLRTManager {
        maxMintAmountPerDay = _maxMintAmountPerDay;
        emit MaxMintAmountPerDayUpdated(_maxMintAmountPerDay);
    }

    /// @notice Permanently add accounts to the exempted list (non-reversible)
    /// @param accounts Accounts to mark as permanently exempt (cannot have transfers blocked)
    function addPermanentExemptions(address[] calldata accounts) external onlyLRTManager {
        uint256 length = accounts.length;

        for (uint256 i = 0; i < length; ++i) {
            address account = accounts[i];
            UtilLib.checkNonZeroAddress(account);

            // Ensure the account is not currently blocked
            uint256 blockedUntil = transfersBlockedUntil[account];
            if (blockedUntil != 0) {
                if (block.timestamp < blockedUntil) {
                    revert CannotPermanentlyExemptBlockedAddress(account, blockedUntil);
                }
                // Auto-clean up expired block
                delete transfersBlockedUntil[account];
            }

            if (!isPermanentlyExempt[account]) {
                isPermanentlyExempt[account] = true;
                emit PermanentExemptionAdded(account);
            }
        }
    }

    /// @notice Block transfers TO and FROM given users for 24 hours
    /// @dev Re-applying the block before expiry refreshes the hold to `block.timestamp + 1 days`
    ///      (i.e. not cumulative; never more than 24h from the latest call). Exempt addresses cannot be blocked.
    ///      Emits {UserTransfersBlocked} only when the timestamp changes.
    /// @param accounts Addresses to block.
    function blockUserTransfers(address[] calldata accounts) external onlyLRTManager {
        uint256 blockedUntil = block.timestamp + 1 days;
        uint256 length = accounts.length;

        for (uint256 i = 0; i < length; ++i) {
            address account = accounts[i];

            if (isPermanentlyExempt[account] || account == address(0)) continue;

            uint256 prevBlockedUntil = transfersBlockedUntil[account];

            if (blockedUntil != prevBlockedUntil) {
                transfersBlockedUntil[account] = blockedUntil;
                emit UserTransfersBlocked(account, blockedUntil);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Pause Management
    //////////////////////////////////////////////////////////////*/

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyRole(LRTConstants.PAUSER_ROLE) {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused.
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the custody address for recovered funds
    /// @param newCustodyAddress The new custody address
    function setCustodyAddress(address newCustodyAddress) external onlyLRTAdmin {
        _setCustodyAddress(newCustodyAddress);
    }

    /// @notice Recover the entire balance from a currently blocked, non-exempt address to a designated custody address
    /// @dev Only callable by LRT admin. Works only while the block is active.
    ///      Emits {FrozenFundsRecovered} even if the recovered amount is zero (for transparency and completeness).
    function recoverFrozenFunds(address from) external onlyLRTAdmin {
        UtilLib.checkNonZeroAddress(from);
        UtilLib.checkNonZeroAddress(custodyAddress);

        if (isPermanentlyExempt[from]) revert AddressPermanentlyExempt(from);

        uint256 blockedUntil = transfersBlockedUntil[from];
        if (blockedUntil == 0 || block.timestamp >= blockedUntil) revert NoActiveTransferBlock(from);

        uint256 accountBalance = balanceOf(from);

        // Bypass transfer block enforcement when transferring to custody address
        super._transfer(from, custodyAddress, accountBalance);
        emit FrozenFundsRecovered(from, custodyAddress, accountBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            Mint & Burn
    //////////////////////////////////////////////////////////////*/

    /// @notice Mints rsETH when called by an authorized caller
    /// @param to the account to mint to
    /// @param amount the amount of rsETH to mint
    function mint(
        address to,
        uint256 amount
    )
        external
        onlyRole(LRTConstants.MINTER_ROLE)
        whenNotPaused
        checkDailyMintLimit(amount)
    {
        _enforceNotBlocked(to);
        _mint(to, amount);
    }

    /// @notice Burns rsETH when called by an authorized caller
    /// @param account the account to burn from
    /// @param amount the amount of rsETH to burn
    function burnFrom(address account, uint256 amount) external onlyRole(LRTConstants.BURNER_ROLE) whenNotPaused {
        _enforceNotBlocked(account);
        _burn(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the aligned start timestamp of the effective current 24-hour minting period, accounting for any
    /// possibly skipped days
    /// @return uint256 The start timestamp of the effective current 24-hour period
    function getCurrentPeriodStartTime() public view returns (uint256) {
        // Calculate the full (complete) days elapsed since the period start time (floors the result)
        uint256 daysElapsed = (block.timestamp - periodStartTime) / 1 days;
        return periodStartTime + daysElapsed * 1 days;
    }

    /// @notice Gets the remaining daily minting limit
    /// @return uint256 The remaining daily minting limit
    function remainingDailyMintLimit() external view returns (uint256) {
        if (maxMintAmountPerDay == 0) return 0;

        // If we're on a new day but no mint has occurred yet, treat currentPeriodMintedAmount as 0
        uint256 effectiveDailyMintAmount = (block.timestamp >= periodStartTime + 1 days) ? 0 : currentPeriodMintedAmount;

        return maxMintAmountPerDay > effectiveDailyMintAmount ? maxMintAmountPerDay - effectiveDailyMintAmount : 0;
    }

    /// @notice Returns the timestamp at which the current effective daily minting period ends,
    /// accounting for any skipped days during which no minting occurred
    /// @dev A mint executed at exactly this timestamp is counted towards the next period's minting limit
    /// @return uint256 The timestamp at which the effective current minting period ends
    function getNextDailyLimitResetTimestamp() external view returns (uint256) {
        return getCurrentPeriodStartTime() + 1 days;
    }

    /*//////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Override ERC20 `_transfer` to enforce transfer blocks on `from` and `to` addresses
    function _transfer(address from, address to, uint256 amount) internal override {
        _enforceNotBlocked(from);
        _enforceNotBlocked(to);
        super._transfer(from, to, amount);
    }

    /// @dev Reverts if `account` is currently blocked (used for transfers, mints, and burns)
    function _enforceNotBlocked(address account) internal {
        // Addresses that are permanently exempt can never be blocked
        if (isPermanentlyExempt[account]) return;

        // Check if the account has an active transfer block
        uint256 blockedUntil = transfersBlockedUntil[account];
        if (blockedUntil == 0) return;

        if (block.timestamp < blockedUntil) revert TransfersBlocked(account, blockedUntil);

        // Auto-clean up expired block
        delete transfersBlockedUntil[account];
    }

    /// @dev Internal function to set the custody address
    function _setCustodyAddress(address newCustodyAddress) internal {
        UtilLib.checkNonZeroAddress(newCustodyAddress);
        custodyAddress = newCustodyAddress;
        emit CustodyAddressUpdated(newCustodyAddress);
    }
}
