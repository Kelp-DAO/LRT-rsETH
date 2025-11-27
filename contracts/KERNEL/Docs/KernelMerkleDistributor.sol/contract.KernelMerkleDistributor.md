# KernelMerkleDistributor
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelMerkleDistributor.sol)

**Inherits:**
[IMerkleDistributor](/contracts/utils/MerkleDistributor/MerkleDistributor.sol/interface.IMerkleDistributor.md), Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable

A contract that distributes KERNEL tokens to users based on a merkle root, and allows users to claim
their tokens and stakes them in the KernelDepositPool contract in a single transaction.


## State Variables
### FEE_DENOMINATOR
The fee denominator constant used to calculate the fee


```solidity
uint256 public constant FEE_DENOMINATOR = 10_000;
```


### kernel
The KERNEL token distributed by this contract


```solidity
IERC20 public kernel;
```


### protocolTreasury
The address of the protocol treasury


```solidity
address public protocolTreasury;
```


### feeInBPS
The fee in basis points


```solidity
uint256 public feeInBPS;
```


### kernelDepositPool
The KernelDepositPool contract address


```solidity
IKernelDepositPool public kernelDepositPool;
```


### currentMerkleRootIndex
The current index of the current merkle root


```solidity
uint256 public currentMerkleRootIndex;
```


### currentMerkleRoot
The current merkle root


```solidity
bytes32 public currentMerkleRoot;
```


### currentIndex
The current index


```solidity
uint256 public currentIndex;
```


### userClaims
The user claims mapping


```solidity
mapping(address user => UserClaim userClaim) public userClaims;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the KernelMerkleDistributor contract


```solidity
function initialize(
    address _kernel,
    address _kernelDepositPool,
    address _protocolTreasury,
    uint256 _feeInBPS
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_kernel`|`address`|The address of the KERNEL token distributed by this contract|
|`_kernelDepositPool`|`address`|The address of the KernelDepositPool contract|
|`_protocolTreasury`|`address`|The address of the protocol treasury|
|`_feeInBPS`|`uint256`|The fee in basis points|


### token

*returns the address of the token distributed by this contract.*


```solidity
function token() external view override returns (address);
```

### isClaimed

*Returns true if the index has been marked claimed.*


```solidity
function isClaimed(uint256 index, address account) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim.|
|`account`|`address`|The address to check if the claim is claimed.|


### claim

*claim the given amount of the token to the given address. Reverts if the inputs are invalid.*


```solidity
function claim(
    uint256 index,
    address account,
    uint256 cumulativeAmount,
    bytes32[] calldata merkleProof
)
    external
    override
    whenNotPaused
    nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|The index of the claim.|
|`account`|`address`|The address to send the token to.|
|`cumulativeAmount`|`uint256`|The cumulative amount of the claim.|
|`merkleProof`|`bytes32[]`|The merkle proof to verify the claim.|


### claimAndStake

Claims the given amount of the tokens for a given address and automatically stakes them in the
KernelDepositPool contract as part of the same transaction


```solidity
function claimAndStake(
    uint256 index,
    address account,
    uint256 cumulativeAmount,
    bytes32[] calldata merkleProof
)
    external
    whenNotPaused
    nonReentrant;
```

### _processClaim

*Internal function to process the claim and calculate the amount to claim*


```solidity
function _processClaim(
    uint256 index,
    address account,
    uint256 cumulativeAmount,
    bytes32[] calldata merkleProof
)
    internal
    returns (uint256);
```

### setKernelDepositPool

Sets the KernelDepositPool contract address


```solidity
function setKernelDepositPool(address _kernelDepositPool) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_kernelDepositPool`|`address`|The address of the new KernelDepositPool contract|


### setProtocolTreasury

Sets the protocol treasury address


```solidity
function setProtocolTreasury(address _protocolTreasury) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_protocolTreasury`|`address`|The address of the new protocol treasury|


### setFeeInBPS

Sets the fee in basis points


```solidity
function setFeeInBPS(uint256 _feeInBPS) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_feeInBPS`|`uint256`|The new fee in basis points|


### setMerkleRoot

Sets the new merkle root


```solidity
function setMerkleRoot(bytes32 _merkleRootToSet) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_merkleRootToSet`|`bytes32`|The new merkle root to be set|


### pause

*Pauses the contract*


```solidity
function pause() external onlyOwner;
```

### unpause

*Unpauses the contract*


```solidity
function unpause() external onlyOwner;
```

## Structs
### UserClaim
The UserClaim struct


```solidity
struct UserClaim {
    uint256 lastClaimedIndex;
    uint256 cumulativeAmount;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`lastClaimedIndex`|`uint256`|The last claimed index|
|`cumulativeAmount`|`uint256`|The cumulative amount claimed|

