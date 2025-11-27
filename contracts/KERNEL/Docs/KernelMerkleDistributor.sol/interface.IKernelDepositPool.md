# IKernelDepositPool
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelMerkleDistributor.sol)

Interface for the KernelDepositPool contract


## Functions
### stakeFor

Allows a user to stake tokens on behalf of another user

*Only STAKE_FOR_ROLE can call this function*


```solidity
function stakeFor(address _account, uint256 _amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_account`|`address`|The address of the account to stake for|
|`_amount`|`uint256`|The amount of staking tokens to stake|


