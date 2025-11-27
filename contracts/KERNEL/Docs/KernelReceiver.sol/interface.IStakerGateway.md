# IStakerGateway
[Git Source](https://github.com/Kelp-DAO/KelpDAO-contracts/blob/654f96a9f687327f83afbd752caa69cdb7e28875/contracts/KERNEL/KernelReceiver.sol)

Interface for the StakerGateway contract from Kernel Protocol, which serves as the
main entry point of the protocol for staking and unstaking tokens.


## Functions
### stakeFor

Allows users to stake assets specifying another address as beneficiary of the deposit

*Staker must provide prior approval to this contract for transfering ERC20 asset*

*Only ROLE_ENABLED_TO_STAKE_FOR can call this function*


```solidity
function stakeFor(address asset, address receiver, uint256 amount, string calldata referralId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|address of the token to stake|
|`receiver`|`address`|the address that will receive the deposit|
|`amount`|`uint256`|amount to stake|
|`referralId`|`string`|the referral id (if any)|


