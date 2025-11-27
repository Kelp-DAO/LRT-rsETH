# KernelDepositPool
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelDepositPool.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable

*Implements a basic staking mechanism with rewards*

*Modified from https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol*


## State Variables
### DECIMAL_PRECISION
The decimal precision used for calculations within the contract


```solidity
uint256 public constant DECIMAL_PRECISION = 1e18;
```


### STAKE_FOR_ROLE
The role required to be able to stake on behalf of another user


```solidity
bytes32 public constant STAKE_FOR_ROLE = keccak256("STAKE_FOR_ROLE");
```


### kernelToken
The KERNEL token contract


```solidity
IERC20 public kernelToken;
```


### rewardsToken
The rewards token contract


```solidity
IERC20 public rewardsToken;
```


### duration
The duration of the rewards distribution


```solidity
uint256 public duration;
```


### finishAt
The timestamp when the rewards distribution ends


```solidity
uint256 public finishAt;
```


### updatedAt
The timestamp when the rewards were last updated


```solidity
uint256 public updatedAt;
```


### rewardRate
The reward rate


```solidity
uint256 public rewardRate;
```


### rewardPerTokenStored
The reward per token stored


```solidity
uint256 public rewardPerTokenStored;
```


### userRewardPerTokenPaid
The latest rewardPerTokenStored checkpoint for each account. It gets updated on each user action


```solidity
mapping(address user => uint256 rewardPerTokenPaid) public userRewardPerTokenPaid;
```


### rewards
Mapping of current rewards for each user


```solidity
mapping(address user => uint256 reward) public rewards;
```


### totalKernelStaked
The total amount of staked KERNEL tokens


```solidity
uint256 public totalKernelStaked;
```


### balanceOf
The balance of staked KERNEL tokens for each user


```solidity
mapping(address user => uint256 stakedBalance) public balanceOf;
```


## Functions
### updateReward

*Modifier to update reward for an account before executing function logic*


```solidity
modifier updateReward(address _account);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account for which rewards will be updated|


### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the KernelDepositPool contract


```solidity
function initialize(address _admin, address _kernelToken, address _rewardToken) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|The address of the admin|
|`_kernelToken`|`address`|Address of the staking token|
|`_rewardToken`|`address`|Address of the rewards token|


### stake

Allows a user to stake a specified amount of staking tokens


```solidity
function stake(uint256 _amount) external nonReentrant updateReward(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount of staking tokens to stake|


### stakeFor

Allows a user to stake tokens on behalf of another user


```solidity
function stakeFor(
    address _account,
    uint256 _amount
)
    external
    nonReentrant
    onlyRole(STAKE_FOR_ROLE)
    updateReward(_account);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The address of the account to stake for|
|`_amount`|`uint256`|The amount of staking tokens to stake|


### withdraw

Allows a user to withdraw staked tokens.


```solidity
function withdraw(uint256 _amount) external nonReentrant updateReward(msg.sender);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount of staking tokens to withdraw.|


### getReward

Allows a user to claim their earned rewards


```solidity
function getReward() external nonReentrant updateReward(msg.sender);
```

### lastTimeRewardApplicable

Returns the last timestamp rewards are applicable


```solidity
function lastTimeRewardApplicable() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last applicable timestamp for rewards|


### rewardPerToken

Calculates the reward per token staked


```solidity
function rewardPerToken() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The calculated reward per token|


### earned

Calculates the amount of rewards earned by an account


```solidity
function earned(address _account) public view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The account to calculate rewards for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of rewards earned.|


### setRewardsDuration

Sets the duration for rewards distribution


```solidity
function setRewardsDuration(uint256 _duration) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_duration`|`uint256`|The duration in seconds for the rewards distribution|


### notifyRewardAmount

Notifies the contract about a new reward amount to be distributed


```solidity
function notifyRewardAmount(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) updateReward(address(0));
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_amount`|`uint256`|The amount of rewards to distribute|


### _min

*Private function to return the minimum of two values*


```solidity
function _min(uint256 x, uint256 y) private pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`x`|`uint256`|First value to compare|
|`y`|`uint256`|Second value to compare|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The minimum value between x and y|


## Events
### Staked
Event emitted when a user stakes KERNEL tokens


```solidity
event Staked(address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens staked|

### StakedFor
Event emitted when the KERNEL tokens are staked on behalf of another user


```solidity
event StakedFor(address indexed sender, address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address of the sender|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens staked|

### Withdrawn
Event emitted when a user withdraws staked KERNEL tokens


```solidity
event Withdrawn(address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens withdrawn|

### RewardsClaimed
Event emitted when a user claims their rewards


```solidity
event RewardsClaimed(address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of rewards claimed|

### RewardsDurationUpdated
Event emitted when the rewards duration is updated


```solidity
event RewardsDurationUpdated(uint256 newDuration);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDuration`|`uint256`|The new duration of the rewards distribution|

### NotifyRewardAmount
Event emitted when the rewards amount is updated


```solidity
event NotifyRewardAmount(uint256 reward, uint256 finishAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reward`|`uint256`|The amount of rewards distributed|
|`finishAt`|`uint256`|The timestamp when the rewards distribution ends|

## Errors
### AmountZero
Error message for an amount of zero


```solidity
error AmountZero();
```

### RewardDurationNotFinished
Error message for a reward duration that has not finished


```solidity
error RewardDurationNotFinished();
```

### RewardAmountGreaterThanBalance
Error message for a reward amount greater than the balance


```solidity
error RewardAmountGreaterThanBalance();
```

### RewardRateZero
Error message for a reward rate of zero


```solidity
error RewardRateZero();
```

