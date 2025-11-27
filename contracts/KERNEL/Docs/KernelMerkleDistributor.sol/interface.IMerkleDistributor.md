# IMerkleDistributor
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelMerkleDistributor.sol)


## Functions
### token

Returns the address of the token distributed by this contract


```solidity
function token() external view returns (address);
```

### isClaimed

Returns true if the index has been marked as claimed


```solidity
function isClaimed(uint256 index, address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim|
|`account`|`address`|The address to check for if the claim is claimed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|true if the claim has been marked claimed, false otherwise|


### claim

Claims the given amount of the token to the given address. Reverts if the inputs are invalid


```solidity
function claim(uint256 index, address account, uint256 cumulativeAmount, bytes32[] calldata merkleProof) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim|
|`account`|`address`|The address to send the token to|
|`cumulativeAmount`|`uint256`|The cumulative amount of the claim|
|`merkleProof`|`bytes32[]`|The merkle proof to verify the claim|


## Events
### Claimed
Event emitted when a user claims their tokens


```solidity
event Claimed(uint256 index, address account, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim|
|`account`|`address`|The address of the user|
|`amount`|`uint256`|The amount of tokens claimed|

### ClaimedAndStaked
Event emitted when a user claims their tokens and stakes them in the KernelDepositPool contract


```solidity
event ClaimedAndStaked(uint256 index, address account, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim|
|`account`|`address`|The address of the user|
|`amount`|`uint256`|The amount of tokens claimed and staked in the KernelDepositPool contract|

### KernelDepositPoolUpdated
Event emitted when the KernelDepositPool contract address is updated


```solidity
event KernelDepositPoolUpdated(address kernelDepositPool);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kernelDepositPool`|`address`|The address of the new KernelDepositPool contract|

### ProtocolTreasuryUpdated
Event emitted when the protocol treasury address is updated


```solidity
event ProtocolTreasuryUpdated(address protocolTreasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`protocolTreasury`|`address`|The address of the new protocol treasury|

### FeeInBPSUpdated
Event emitted when the fee in basis points is updated


```solidity
event FeeInBPSUpdated(uint256 feeInBPS);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feeInBPS`|`uint256`|The new fee in basis points|

### MerkleRootSet
Event emitted when the merkle root is set


```solidity
event MerkleRootSet(uint256 index, bytes32 currentMerkleRoot);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the merkle root|
|`currentMerkleRoot`|`bytes32`|The current merkle root|

## Errors
### ZeroValueProvided
Error message for a zero value provided as input (e.g. 0 for uint256 or bytes32(0) for bytes32)


```solidity
error ZeroValueProvided();
```

### NoTokensToClaim
Error message for when there are no tokens to claim


```solidity
error NoTokensToClaim();
```

### AlreadyClaimed
Error message for when the user has already claimed


```solidity
error AlreadyClaimed();
```

### InvalidMerkleProof
Error message for an invalid merkle proof


```solidity
error InvalidMerkleProof();
```

### InvalidIndex
Error message for an invalid index


```solidity
error InvalidIndex();
```

### InvalidFeeInBPS
Error message for an invalid fee in basis points


```solidity
error InvalidFeeInBPS();
```

