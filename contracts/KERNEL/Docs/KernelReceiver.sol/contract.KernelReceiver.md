# KernelReceiver
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelReceiver.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable

This contract is responsible for being the intermediary destination of KERNEL tokens that are
bridged from Ethereum mainnet to the Binance Smart Chain (BSC) via LayerZero, and it’s through this
contract that the restaking deposits on behalf of the users are made.


## State Variables
### OPERATOR_ROLE
The operator role within the contract


```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```


### kernel
The KERNEL token contract on BSC (Binance Smart Chain)


```solidity
IERC20 public kernel;
```


### stakerGateway
Reference to the IStakerGateway contract from Kernel Protocol


```solidity
IStakerGateway public stakerGateway;
```


### lastStakedDepositId
The last deposit ID that was staked by the operator


```solidity
uint256 public lastStakedDepositId;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the KernelReceiver contract


```solidity
function initialize(address _admin, address _operator, address _kernel, address _stakerGateway) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|The address of the admin role|
|`_operator`|`address`|The address of the operator role|
|`_kernel`|`address`|The address of the KERNEL token contract on BSC|
|`_stakerGateway`|`address`|The address of the StakerGateway contract|


### stakeFor

Restakes the KERNEL tokens on behalf of the user, based on their deposit from the Ethereum mainnet


```solidity
function stakeFor(address user, uint256 amount) external whenNotPaused nonReentrant onlyRole(OPERATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens to be restaked in the Kernel Protocol|


### batchStakeFor

Restakes the KERNEL tokens on behalf of multiple users, based on their deposits from the Ethereum mainnet


```solidity
function batchStakeFor(
    address[] calldata users,
    uint256[] calldata amounts
)
    external
    whenNotPaused
    nonReentrant
    onlyRole(OPERATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`users`|`address[]`|The addresses of the users|
|`amounts`|`uint256[]`|The amounts of KERNEL tokens to be restaked in the Kernel Protocol|


### setStakerGateway

Sets the StakerGateway contract address


```solidity
function setStakerGateway(address _stakerGateway) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_stakerGateway`|`address`|The address of the new StakerGateway contract|


### pause

Pauses the contract


```solidity
function pause() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### unpause

Unpauses the contract


```solidity
function unpause() external onlyRole(DEFAULT_ADMIN_ROLE);
```

### _stakeFor

Internal function to stake KERNEL tokens on behalf of a user


```solidity
function _stakeFor(address user, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens to be staked|


## Events
### KernelStakedFor
Event emitted when the operator stakes KERNEL tokens on behalf of a user


```solidity
event KernelStakedFor(address indexed user, uint256 indexed amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens staked|

### StakerGatewayUpdated
Event emitted when the StakerGateway contract address is updated


```solidity
event StakerGatewayUpdated(address indexed newStakerGateway, address indexed oldStakerGateway);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newStakerGateway`|`address`|The address of the new StakerGateway contract|
|`oldStakerGateway`|`address`|The address of the old StakerGateway contract|

## Errors
### InvalidKernelAmount
Error message for an invalid KERNEL token amount


```solidity
error InvalidKernelAmount();
```

### ZeroArrayLength
Error message for an array with zero length


```solidity
error ZeroArrayLength();
```

### ArrayLengthMismatch
Error message for an array length mismatch


```solidity
error ArrayLengthMismatch();
```

