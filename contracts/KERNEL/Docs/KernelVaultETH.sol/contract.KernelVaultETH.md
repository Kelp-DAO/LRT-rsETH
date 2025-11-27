# KernelVaultETH
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelVaultETH.sol)

**Inherits:**
Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable

This contract is responsible for managing the deposits of KERNEL tokens on Ethereum mainnet and bridging them
to the Binance Smart Chain (BSC) via LayerZero where they will be restaked in the Kernel Protocol.


## State Variables
### OPERATOR_ROLE
The operator role within the contract


```solidity
bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
```


### MERKLE_DISTRIBUTOR_ROLE
The merkle distributor role within the contract (can deposit on behalf of users)


```solidity
bytes32 public constant MERKLE_DISTRIBUTOR_ROLE = keccak256("MERKLE_DISTRIBUTOR_ROLE");
```


### kernel
The KERNEL token contract on Ethereum mainnet


```solidity
IERC20 public kernel;
```


### kernelOftAdapter
The Kernel OFT adapter contract


```solidity
IKERNEL_OFTAdapter public kernelOftAdapter;
```


### dstLzChainId
The LayerZero chain ID of the BSC chain


```solidity
uint32 public dstLzChainId;
```


### receiver
The address of the intended target (receiver) contract on the BSC chain


```solidity
address public receiver;
```


### minDeposit
The minimum amount of KERNEL tokens expected for a deposit


```solidity
uint256 public minDeposit;
```


### counter
The next deposit ID to be set


```solidity
uint256 public counter;
```


### lastBridgedDepositId
The deposit ID of the last bridged deposit


```solidity
uint256 public lastBridgedDepositId;
```


### userDeposits
The mapping of the deposit ID to the user deposit


```solidity
mapping(uint256 depositId => UserDeposit userDeposit) public userDeposits;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

*Initialize the KernelVaultETH contract*


```solidity
function initialize(
    address _admin,
    address _operator,
    address _kernel,
    address _kernelOftAdapter,
    uint32 _dstLzChainId,
    address _receiver,
    uint256 _minDeposit
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_admin`|`address`|The address of the admin role|
|`_operator`|`address`|The address of the operator role|
|`_kernel`|`address`|The address of the KERNEL token contract on Ethereum mainnet|
|`_kernelOftAdapter`|`address`|The address of the Kernel OFT adapter|
|`_dstLzChainId`|`uint32`|The LayerZero chain ID of the BSC chain|
|`_receiver`|`address`|The address of the intended target (receiver) contract on the BSC chain|
|`_minDeposit`|`uint256`|The minimum amount of KERNEL tokens expected for a deposit|


### depositKernel

Deposits KERNEL tokens into the vault


```solidity
function depositKernel(uint256 amount) external whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of KERNEL tokens to deposit|


### depositKernelFor

Deposits KERNEL tokens into the vault on behalf of a user


```solidity
function depositKernelFor(
    address user,
    uint256 amount
)
    external
    whenNotPaused
    nonReentrant
    onlyRole(MERKLE_DISTRIBUTOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens to deposit|


### bridgeKernelToBSC

Bridges KERNEL tokens to the BSC chain


```solidity
function bridgeKernelToBSC(
    uint256 amount,
    uint256 minAmount,
    uint256 nativeFee,
    address refundAddress
)
    external
    payable
    nonReentrant
    onlyRole(OPERATOR_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of KERNEL tokens to bridge|
|`minAmount`|`uint256`|The minimum amount of KERNEL tokens to receive on BSC|
|`nativeFee`|`uint256`|The native fee to pay for the bridge|
|`refundAddress`|`address`|The address to refund the native fee to in case of a failed bridge transaction|


### setDstLzChainId

Sets the LayerZero chain ID of the BSC chain


```solidity
function setDstLzChainId(uint32 _dstLzChainId) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_dstLzChainId`|`uint32`|The new LayerZero chain ID of the BSC chain|


### setReceiver

Sets the receiver address


```solidity
function setReceiver(address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_receiver`|`address`|The new address of the intended target (receiver) contract on the BSC chain|


### setMinDeposit

Sets the minimum deposit amount


```solidity
function setMinDeposit(uint256 _minDeposit) external onlyRole(DEFAULT_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_minDeposit`|`uint256`|The new minimum amount of KERNEL tokens expected for a deposit|


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

### getNativeFee

*Quotes the native fee for bridging KERNEL tokens to BSC*


```solidity
function getNativeFee(uint256 amount, uint256 minAmount) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount of KERNEL tokens to bridge|
|`minAmount`|`uint256`|The minimum amount of KERNEL tokens to receive on BSC|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The fee to be paid in native currency|


### getReceiver

*Get the receiver address in the bytes32 format*


```solidity
function getReceiver() public view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The receiver address in the bytes32 format|


### getUserDeposit

*Get the user deposit details*


```solidity
function getUserDeposit(uint256 depositId) external view returns (UserDeposit memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`uint256`|The deposit ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`UserDeposit`|The user deposit details (user address and amount)|


### _depositKernel

*Internal function to deposit KERNEL tokens into the vault*


```solidity
function _depositKernel(address user, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens to deposit|


## Events
### KernelVaultETHDeposit
Event emitted when a user deposits KERNEL tokens into the vault


```solidity
event KernelVaultETHDeposit(uint256 depositId, address indexed user, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositId`|`uint256`|The deposit ID of the deposit|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens deposited|

### BridgedKernelToBSC
Event emitted when KERNEL tokens are bridged to the BSC chain


```solidity
event BridgedKernelToBSC(
    uint32 indexed lzChainId,
    address indexed receiver,
    uint256 amount,
    uint256 minAmount,
    uint256 nativeFee,
    uint256 lastBridgedDepositId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`lzChainId`|`uint32`|The LayerZero chain ID of the BSC chain|
|`receiver`|`address`|The address of the intended target (receiver) contract on the BSC chain|
|`amount`|`uint256`|The amount of KERNEL tokens bridged|
|`minAmount`|`uint256`|The minimum amount of KERNEL tokens expected on the BSC chain|
|`nativeFee`|`uint256`|The native fee paid for the bridge|
|`lastBridgedDepositId`|`uint256`|The deposit ID of the last bridged deposit|

### DstLzChainIdUpdated
Event emitted when the LayerZero chain ID of the BSC chain is updated


```solidity
event DstLzChainIdUpdated(uint32 indexed newDstLzChainId, uint32 indexed oldDstLzChainId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDstLzChainId`|`uint32`|The new LayerZero chain ID of the BSC chain|
|`oldDstLzChainId`|`uint32`|The old LayerZero chain ID of the BSC chain|

### ReceiverUpdated
Event emitted when the receiver address is updated


```solidity
event ReceiverUpdated(address indexed newReceiver, address indexed oldReceiver);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newReceiver`|`address`|The new address of the intended target (receiver) contract on the BSC chain|
|`oldReceiver`|`address`|The old address of the intended target (receiver) contract on the BSC chain|

### MinDepositUpdated
Event emitted when the minimum deposit amount is updated


```solidity
event MinDepositUpdated(uint256 indexed newMinDeposit, uint256 indexed oldMinDeposit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMinDeposit`|`uint256`|The new minimum amount of KERNEL tokens expected for a deposit|
|`oldMinDeposit`|`uint256`|The old minimum amount of KERNEL tokens expected for a deposit|

## Errors
### InvalidLzChainId
Error message for when admin tries to set the invalid LayerZero chain ID


```solidity
error InvalidLzChainId();
```

### InvalidMinDeposit
Error message for when admin tries to set the invalid minimum deposit amount


```solidity
error InvalidMinDeposit();
```

### DepositAmountTooLow
Error message for when user tries to deposit an amount lower than the minimum


```solidity
error DepositAmountTooLow();
```

### InsufficientKernelBalance
Error message for when the contract has insufficient KERNEL tokens to bridge


```solidity
error InsufficientKernelBalance();
```

### InvalidMinAmount
Error message for an invalid minimum amount of KERNEL tokens expected on BSC after bridging


```solidity
error InvalidMinAmount();
```

### InsufficientNativeFee
Error message for an insufficient native fee sent for the bridge transaction


```solidity
error InsufficientNativeFee();
```

## Structs
### UserDeposit
Struct representing a user deposit


```solidity
struct UserDeposit {
    address user;
    uint256 amount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the user|
|`amount`|`uint256`|The amount of KERNEL tokens deposited|

