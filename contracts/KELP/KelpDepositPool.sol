// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title Kelp Staking Rewards Contract
/// @dev Implements a basic staking mechanism with rewards.
/// @dev modified from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
contract KelpDepositPool is Initializable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public kelpToken;
    IERC20Upgradeable public rewardsToken;

    address public admin;

    uint256 public duration;
    uint256 public finishAt;
    uint256 public updatedAt;
    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 public totalKelpStaked;
    mapping(address => uint256) public balanceOf;

    error NotAuthorized();
    error AmountZero();
    error RewardDurationNotFinished();
    error RewardAmountGreaterThanBalance();
    error RewardRateZero();

    /// @dev Modifier to restrict functions to the contract's admin.
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAuthorized();
        _;
    }

    /// @dev Modifier to update reward for an account before executing function logic.
    /// @param _account The account for which rewards will be updated.
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

    /// @dev Initializes the contract with staking and rewards tokens addresses.
    /// @param _admin The address of the admin.
    /// @param _kelpToken Address of the staking token.
    /// @param _rewardToken Address of the rewards token.
    function initialize(
        address _admin,
        address _kelpToken,
        address _rewardToken,
        uint256 _duration
    )
        public
        initializer
    {
        admin = _admin;
        kelpToken = IERC20Upgradeable(_kelpToken);
        rewardsToken = IERC20Upgradeable(_rewardToken);
        duration = _duration;
    }

    /// @dev Returns the last timestamp rewards are applicable.
    /// @return The last applicable timestamp for rewards.
    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(finishAt, block.timestamp);
    }

    /// @dev Calculates the reward per token staked.
    /// @return The calculated reward per token.
    function rewardPerToken() public view returns (uint256) {
        if (totalKelpStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) / totalKelpStaked;
    }

    /// @dev Allows a user to stake a specified amount of staking tokens.
    /// @param _amount The amount of staking tokens to stake.
    function stake(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        if (_amount == 0) revert AmountZero();
        balanceOf[msg.sender] += _amount;
        totalKelpStaked += _amount;
        kelpToken.safeTransferFrom(msg.sender, address(this), _amount);
    }

    /// @dev Allows a user to withdraw staked tokens.
    /// @param _amount The amount of staking tokens to withdraw.
    function withdraw(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        if (_amount == 0) revert AmountZero();
        balanceOf[msg.sender] -= _amount;
        totalKelpStaked -= _amount;
        kelpToken.safeTransfer(msg.sender, _amount);
    }

    /// @dev Calculates the amount of rewards earned by an account.
    /// @param _account The account to calculate rewards for.
    /// @return The amount of rewards earned.
    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account]) / 1e18) + rewards[_account];
    }

    /// @dev Allows a user to claim their earned rewards.
    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Sets the duration for rewards distribution.
    /// @param _duration The duration in seconds for the rewards distribution.
    function setRewardsDuration(uint256 _duration) external onlyAdmin {
        if (finishAt >= block.timestamp) revert RewardDurationNotFinished();
        duration = _duration;
    }

    /// @dev Notifies the contract about a new reward amount to be distributed.
    /// @param _amount The amount of rewards to distribute.
    function notifyRewardAmount(uint256 _amount) external onlyAdmin updateReward(address(0)) {
        if (_amount > rewardsToken.balanceOf(address(this))) revert RewardAmountGreaterThanBalance();

        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint256 remaining = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remaining) / duration;
        }

        if (rewardRate == 0) revert RewardRateZero();
        if (rewardRate * duration > rewardsToken.balanceOf(address(this))) revert RewardAmountGreaterThanBalance();
        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Private function to return the minimum of two values.
    /// @param x First value to compare.
    /// @param y Second value to compare.
    /// @return The minimum value between x and y.
    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
