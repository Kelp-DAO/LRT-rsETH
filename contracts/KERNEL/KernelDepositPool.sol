// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title Kernel Staking Rewards Contract
 * @dev Implements a basic staking mechanism with rewards
 * @dev Modified from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
 * @dev If `totalKernelStaked` ever hits zero during a reward distribution window, any remaining rewards
 *      for that period will stay locked in the contract. In this deployment, we're avoiding this issue by
 *      ensuring there are always some tokens staked before admin calls the `notifyRewardAmount` function,
 *      as well as for the entire duration of the reward period. Otherwise, staking just 1 wei by any address
 *      will ensure that the contract never has any unallocated rewards.
 */
contract KernelDepositPool is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice The decimal precision used for calculations within the contract
    uint256 public constant DECIMAL_PRECISION = 1e18;

    /// @notice The maximum withdrawal delay allowed
    uint256 public constant MAX_WITHDRAWAL_DELAY = 30 days;

    /// @notice The maximum number of open (unclaimed) withdrawals allowed per user at any time
    uint256 public constant MAX_WITHDRAWALS_PER_USER = 100;

    /// @notice The role required to stake on behalf of another user
    bytes32 public constant STAKE_FOR_ROLE = keccak256("STAKE_FOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents a pending withdrawal initiated by a user.
     */
    struct Withdrawal {
        address user; // The user who initiated the withdrawal
        uint256 amount; // Amount of KERNEL tokens to withdraw
        uint256 unlockTime; // When the withdrawal becomes claimable
        bool claimed; // Whether the withdrawal has been claimed
        uint256 withdrawalId; // The ID of the withdrawal
    }

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The KERNEL token contract (used for staking)
    IERC20 public kernelToken;

    /// @notice The rewards token contract
    IERC20 public rewardsToken;

    /// @notice The duration of the rewards distribution
    uint256 public duration;

    /// @notice The timestamp when rewards distribution ends
    uint256 public finishAt;

    /// @notice The timestamp when the rewards were last updated
    uint256 public updatedAt;

    /// @notice The reward rate
    uint256 public rewardRate;

    /// @notice The reward per token stored
    uint256 public rewardPerTokenStored;

    /// @notice The latest rewardPerTokenStored checkpoint for each account. It gets updated on each user action
    mapping(address user => uint256 rewardPerTokenPaid) public userRewardPerTokenPaid;

    /// @notice Mapping of current accumulated rewards that have not been claimed for each user
    mapping(address user => uint256 reward) public rewards;

    /// @notice The total amount of staked KERNEL tokens
    uint256 public totalKernelStaked;

    /// @notice The balance of staked KERNEL tokens for each user
    mapping(address user => uint256 stakedBalance) public balanceOf;

    /// @notice Delay (in seconds) before withdrawals can be claimed after initiation
    uint256 public withdrawalDelay;

    /// @notice A global incremental counter for withdrawal IDs
    uint256 public withdrawalCounter;

    /// @notice Mapping of withdrawal IDs to their withdrawal info
    mapping(uint256 withdrawalId => Withdrawal withdrawal) public withdrawals;

    /// @notice Mapping of user addresses to their withdrawal IDs
    mapping(address user => uint256[] withdrawalIds) public userWithdrawalIds;

    /// @notice The maximum number of withdrawals that any user can have open (unclaimed) at any time
    uint256 public maxNumberOfWithdrawalsPerUser;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a user stakes KERNEL tokens
     * @param user The address of the user
     * @param amount The amount of KERNEL tokens staked
     */
    event Staked(address indexed user, uint256 amount);

    /**
     * @notice Event emitted when the KERNEL tokens are staked on behalf of another user
     * @param sender The address of the sender
     * @param user The address of the user
     * @param amount The amount of KERNEL tokens staked
     */
    event StakedFor(address indexed sender, address indexed user, uint256 amount);

    /**
     * @notice Event emitted when a user initiates a KERNEL token withdrawal
     * @param user The user who initiated withdrawal
     * @param amount The amount of KERNEL tokens to eventually withdraw
     * @param withdrawalId The ID of the created withdrawal request
     * @param unlockTime The timestamp after which the user can claim their KERNEL tokens
     */
    event WithdrawalInitiated(address indexed user, uint256 amount, uint256 withdrawalId, uint256 unlockTime);

    /**
     * @notice Event emitted when a user claims a previously initiated withdrawal
     * @param user The user who claimed
     * @param amount The amount of KERNEL tokens claimed
     * @param withdrawalId The ID of the withdrawal claimed
     */
    event WithdrawalClaimed(address indexed user, uint256 amount, uint256 withdrawalId);

    /**
     * @notice Event emitted when a user claims their rewards
     * @param user The address of the user
     * @param amount The amount of rewards claimed
     */
    event RewardsClaimed(address indexed user, uint256 amount);

    /**
     * @notice Event emitted when the rewards duration is updated
     * @param newDuration The new duration of the rewards distribution
     */
    event RewardsDurationUpdated(uint256 newDuration);

    /**
     * @notice Event emitted when the rewards amount is updated
     * @param reward The amount of rewards distributed
     * @param finishAt The timestamp when the rewards distribution ends
     */
    event NotifyRewardAmount(uint256 reward, uint256 finishAt);

    /**
     * @notice Event emitted when the withdrawal delay is updated
     * @param newDelay The new withdrawal delay
     */
    event WithdrawalDelayUpdated(uint256 newDelay);

    /**
     * @notice Event emitted when the maximum number of withdrawals per user is updated
     * @param newMaxNumberOfWithdrawalsPerUser The new maximum number of withdrawals per user
     */
    event MaxNumberOfWithdrawalsPerUserUpdated(uint256 newMaxNumberOfWithdrawalsPerUser);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error message for an invalid withdrawal delay
    error InvalidWithdrawalDelay();

    /// @notice Error message for an amount of zero
    error AmountZero();

    /// @notice Error message for an insufficient staked balance
    error InsufficientStakedBalance();

    /// @notice Error message for a withdrawal that does not exist
    error WithdrawalDoesNotExist();

    /// @notice Error message for a withdrawal that is not yours
    error NotYourWithdrawal();

    /// @notice Error message for a withdrawal that is not ready to be claimed
    error WithdrawalNotReady();

    /// @notice Error message for a withdrawal that has already been claimed
    error WithdrawalAlreadyClaimed();

    /// @notice Error message for a reward duration that has not finished
    error RewardDurationNotFinished();

    /// @notice Error message for an invalid rewards duration
    error InvalidDuration();

    /// @notice Error message for when there are no staked tokens
    error NoStakedTokens();

    /// @notice Error message for a reward rate of zero
    error RewardRateZero();

    /// @notice Error message for a withdrawal limit reached
    error WithdrawalLimitReached();

    /// @notice Error message for when the maximum withdrawal delay is exceeded
    error MaximumWithdrawalDelayExceeded();

    /// @notice Error message for an invalid maximum number of withdrawals per user
    error InvalidMaxNumberOfWithdrawalsPerUser();

    /*//////////////////////////////////////////////////////////////
                         MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to update reward for an account before executing function logic
     * @param _account The account whose rewards are updated
     */
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the KernelDepositPool contract
     * @param _admin The address of the admin
     * @param _kernelToken The address of the staking token
     * @param _rewardToken The address of the rewards token
     */
    function initialize(address _admin, address _kernelToken, address _rewardToken) external initializer {
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_kernelToken);
        UtilLib.checkNonZeroAddress(_rewardToken);

        __AccessControl_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);

        kernelToken = IERC20(_kernelToken);
        rewardsToken = IERC20(_rewardToken);
    }

    /*//////////////////////////////////////////////////////////////
                      USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows a user to stake a specified amount of KERNEL tokens
     * @param _amount The amount of staking tokens to stake
     */
    function stake(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        if (_amount == 0) revert AmountZero();

        balanceOf[msg.sender] += _amount;
        totalKernelStaked += _amount;
        kernelToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    /**
     * @notice Allows an account with STAKE_FOR_ROLE to stake KERNEL tokens on behalf of another user
     * @param _account The account for which tokens are staked
     * @param _amount The amount of tokens to stake
     */
    function stakeFor(
        address _account,
        uint256 _amount
    )
        external
        nonReentrant
        onlyRole(STAKE_FOR_ROLE)
        updateReward(_account)
    {
        UtilLib.checkNonZeroAddress(_account);

        if (_amount == 0) revert AmountZero();

        balanceOf[_account] += _amount;
        totalKernelStaked += _amount;
        kernelToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit StakedFor(msg.sender, _account, _amount);
    }

    /**
     * @notice Initiate a withdrawal by setting a timer to claim the underlying KERNEL tokens
     * @param _amount The amount of KERNEL to eventually withdraw
     */
    function initiateWithdrawal(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        if (_amount == 0) revert AmountZero();
        if (balanceOf[msg.sender] < _amount) revert InsufficientStakedBalance();
        if (userWithdrawalIds[msg.sender].length > maxNumberOfWithdrawalsPerUser) revert WithdrawalLimitReached();

        balanceOf[msg.sender] -= _amount;
        totalKernelStaked -= _amount;

        // Create a withdrawal record
        uint256 withdrawalId = ++withdrawalCounter;
        uint256 unlockTime = block.timestamp + withdrawalDelay;

        withdrawals[withdrawalId] = Withdrawal({
            user: msg.sender,
            amount: _amount,
            unlockTime: unlockTime,
            claimed: false,
            withdrawalId: withdrawalId
        });
        userWithdrawalIds[msg.sender].push(withdrawalId);

        emit WithdrawalInitiated(msg.sender, _amount, withdrawalId, unlockTime);
    }

    /**
     * @notice Claim a previously initiated withdrawal after the delay has passed
     * @param _withdrawalId The ID of the withdrawal to claim
     */
    function claimWithdrawal(uint256 _withdrawalId) external nonReentrant {
        Withdrawal storage withdrawal = withdrawals[_withdrawalId];

        if (withdrawal.user == address(0)) {
            revert WithdrawalDoesNotExist();
        }

        if (withdrawal.user != msg.sender) {
            revert NotYourWithdrawal();
        }

        if (block.timestamp < withdrawal.unlockTime) {
            revert WithdrawalNotReady();
        }

        if (withdrawal.claimed) {
            revert WithdrawalAlreadyClaimed();
        }

        withdrawal.claimed = true;

        // Remove the withdrawal ID from the user's list of withdrawal IDs
        uint256[] storage userWithdrawalIdsArray = userWithdrawalIds[msg.sender];
        for (uint256 i = 0; i < userWithdrawalIdsArray.length; ++i) {
            if (userWithdrawalIdsArray[i] == _withdrawalId) {
                userWithdrawalIdsArray[i] = userWithdrawalIdsArray[userWithdrawalIdsArray.length - 1];
                userWithdrawalIdsArray.pop();
                break;
            }
        }

        // Transfer the KERNEL tokens from contract to user
        kernelToken.safeTransfer(msg.sender, withdrawal.amount);

        emit WithdrawalClaimed(msg.sender, withdrawal.amount, _withdrawalId);
    }

    /// @notice Allows a user to claim their earned rewards
    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 rewardAmount = rewards[msg.sender];

        if (rewardAmount > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, rewardAmount);
            emit RewardsClaimed(msg.sender, rewardAmount);
        }
    }

    /*/////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the last time rewards are applicable
     * @return The last applicable timestamp
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return finishAt < block.timestamp ? finishAt : block.timestamp;
    }

    /**
     * @notice Calculates the reward per token staked
     * @return The calculated reward per token
     */
    function rewardPerToken() public view returns (uint256) {
        if (totalKernelStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored
            + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * DECIMAL_PRECISION) / totalKernelStaked;
    }

    /**
     * @notice Calculates the amount of rewards earned by an account
     * @param _account The account to for which rewards are calculated
     * @return The earned reward amount
     */
    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account]) / DECIMAL_PRECISION)
            + rewards[_account];
    }

    /**
     * @notice Returns the withdrawal IDs for a given user
     * @param _user The user for which to retrieve withdrawal IDs
     * @return The withdrawal IDs
     */
    function getUserWithdrawalIds(address _user) external view returns (uint256[] memory) {
        return userWithdrawalIds[_user];
    }

    /**
     * @notice Returns the withdrawal details for a given withdrawal ID
     * @param _withdrawalId The ID of the withdrawal to retrieve
     * @return The withdrawal details
     */
    function getWithdrawal(uint256 _withdrawalId) external view returns (Withdrawal memory) {
        return withdrawals[_withdrawalId];
    }

    /**
     * @notice Returns all of the currently unclaimed withdrawals for a given user
     * @param _user The user for which to retrieve withdrawals
     * @return The withdrawals
     */
    function getUserWithdrawals(address _user) public view returns (Withdrawal[] memory) {
        uint256[] memory withdrawalIds = userWithdrawalIds[_user];
        Withdrawal[] memory userWithdrawals = new Withdrawal[](withdrawalIds.length);

        if (withdrawalIds.length == 0) {
            return userWithdrawals;
        }

        for (uint256 i = 0; i < withdrawalIds.length; ++i) {
            userWithdrawals[i] = withdrawals[withdrawalIds[i]];
        }

        return userWithdrawals;
    }

    /**
     * @notice Returns all of the currently pending (non-claimable) withdrawals for a given use
     * @param _user The user for which to retrieve withdrawals
     * @return The withdrawals
     */
    function getPendingUserWithdrawals(address _user) external view returns (Withdrawal[] memory) {
        Withdrawal[] memory userWithdrawals = getUserWithdrawals(_user);

        if (userWithdrawals.length == 0) {
            return userWithdrawals;
        }

        uint256 pendingCount = 0;
        for (uint256 i = 0; i < userWithdrawals.length; ++i) {
            if (block.timestamp < userWithdrawals[i].unlockTime) {
                ++pendingCount;
            }
        }

        Withdrawal[] memory pendingWithdrawals = new Withdrawal[](pendingCount);
        uint256 pendingIndex = 0;
        for (uint256 i = 0; i < userWithdrawals.length; ++i) {
            if (block.timestamp < userWithdrawals[i].unlockTime) {
                pendingWithdrawals[pendingIndex] = userWithdrawals[i];
                ++pendingIndex;
            }
        }

        return pendingWithdrawals;
    }

    /**
     * @notice Returns all of the currently claimable withdrawals for a given user
     * @param _user The user for which to retrieve withdrawals
     * @return The withdrawals
     */
    function getClaimableUserWithdrawals(address _user) external view returns (Withdrawal[] memory) {
        Withdrawal[] memory userWithdrawals = getUserWithdrawals(_user);

        if (userWithdrawals.length == 0) {
            return userWithdrawals;
        }

        uint256 claimableCount = 0;
        for (uint256 i = 0; i < userWithdrawals.length; ++i) {
            if (block.timestamp >= userWithdrawals[i].unlockTime) {
                ++claimableCount;
            }
        }

        Withdrawal[] memory claimableWithdrawals = new Withdrawal[](claimableCount);
        uint256 claimableIndex = 0;
        for (uint256 i = 0; i < userWithdrawals.length; ++i) {
            if (block.timestamp >= userWithdrawals[i].unlockTime) {
                claimableWithdrawals[claimableIndex] = userWithdrawals[i];
                ++claimableIndex;
            }
        }

        return claimableWithdrawals;
    }

    /**
     * @notice Returns whether a withdrawal is ready to be claimed
     * @param _withdrawalId The ID of the withdrawal to check
     * @return Whether the withdrawal is ready to be claimed
     */
    function isWithdrawalClaimable(uint256 _withdrawalId) external view returns (bool) {
        return block.timestamp >= withdrawals[_withdrawalId].unlockTime;
    }

    /**
     * @notice Returns whether a withdrawal has been claimed
     * @param _withdrawalId The ID of the withdrawal to check
     * @return Whether the withdrawal has been claimed
     */
    function isWithdrawalClaimed(uint256 _withdrawalId) external view returns (bool) {
        return withdrawals[_withdrawalId].claimed;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the duration for rewards distribution
     * @param _duration The duration in seconds
     */
    function setRewardsDuration(uint256 _duration) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (finishAt >= block.timestamp) revert RewardDurationNotFinished();
        if (_duration == 0) revert InvalidDuration();
        duration = _duration;
        emit RewardsDurationUpdated(_duration);
    }

    /**
     * @notice Notifies the contract about a new reward amount
     * @dev Uses a transfer-in pattern to determine the exact reward amount received.
     *      Also, to avoid undistributed rewards when no one is staked, this function reverts if totalKernelStaked is
     *      zero.
     * @param _amount The amount of reward tokens to add
     */
    function notifyRewardAmount(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0)) {
        if (_amount == 0) revert AmountZero();

        // Prevent starting a reward period when no tokens are staked to avoid unallocated rewards
        if (totalKernelStaked == 0) revert NoStakedTokens();

        // Transfer reward tokens into the contract
        uint256 balanceBefore = rewardsToken.balanceOf(address(this));
        rewardsToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 balanceAfter = rewardsToken.balanceOf(address(this));
        // Calculate the actual amount of tokens received in case of a transfer fee (tax)
        uint256 receivedAmount = balanceAfter - balanceBefore;

        if (block.timestamp >= finishAt) {
            rewardRate = receivedAmount / duration;
        } else {
            uint256 remaining = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (receivedAmount + remaining) / duration;
        }

        if (rewardRate == 0) revert RewardRateZero();

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;

        emit NotifyRewardAmount(receivedAmount, finishAt);
    }

    /**
     * @notice Updates the withdrawal delay
     * @param _withdrawalDelay The new withdrawal delay
     */
    function setWithdrawalDelay(uint256 _withdrawalDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_withdrawalDelay == 0) revert InvalidWithdrawalDelay();
        if (_withdrawalDelay > MAX_WITHDRAWAL_DELAY) revert MaximumWithdrawalDelayExceeded();

        withdrawalDelay = _withdrawalDelay;
        emit WithdrawalDelayUpdated(_withdrawalDelay);
    }

    /**
     * @notice Updates the maximum number of withdrawals per user
     * @param _maxNumberOfWithdrawalsPerUser The new maximum number of withdrawals per user
     */
    function setMaxNumberOfWithdrawalsPerUser(uint256 _maxNumberOfWithdrawalsPerUser)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_maxNumberOfWithdrawalsPerUser == 0 || _maxNumberOfWithdrawalsPerUser > MAX_WITHDRAWALS_PER_USER) {
            revert InvalidMaxNumberOfWithdrawalsPerUser();
        }

        maxNumberOfWithdrawalsPerUser = _maxNumberOfWithdrawalsPerUser;
        emit MaxNumberOfWithdrawalsPerUserUpdated(_maxNumberOfWithdrawalsPerUser);
    }
}
