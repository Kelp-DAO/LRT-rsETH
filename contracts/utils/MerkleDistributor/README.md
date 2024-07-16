# MerkleDistributor Contract Documentation

## Overview

The `MerkleDistributor` contract allows users to claim ERC20 tokens based on their entitlements stored in Merkle trees. This implementation is designed to optimize the claiming process, enabling users to claim their cumulative entitlement in a single transaction, regardless of how many distribution periods have passed since their last claim.

## Contract Functions

### Public and External Functions

- `token() external view returns (address)`: Returns the address of the ERC20 token distributed by this contract.
- `isClaimed(uint256 index, address account) external view returns (bool)`: Checks if the root has already been claimed by an account.
- `claim(uint256 index, address account, uint256 cumulativeAmount, bytes32[] calldata merkleProof) external`: Allows a user to claim their tokens based on a Merkle proof. If the claim is valid, the user's account is credited with the specified amount of tokens. If user already claimed tokens for the given merkle root index, the function reverts.

### Events

- `Claimed(uint256 index, address account, uint256 amount)`: Emitted after a successful claim.
- `MerkleRootSet(uint256 index, bytes32 merkleRoot)`: Emitted after a new Merkle root is set in the contract by the owner.

## How to Use the Contract

### Claiming Tokens

To claim tokens, a user needs to provide:
- The `index` corresponding to their position in the Merkle tree.
- Their `account` address where the tokens will be sent.
- The `cumulativeAmount` representing the total amount they are entitled to claim up to the current period.
- A valid `merkleProof` proving their entitlement.

The contract calculates the actual claimable amount by subtracting any previously claimed amount from the `cumulativeAmount`. If the claim is valid and there are tokens to claim, the specified amount is transferred to the user's account.

### Verifying Claim Eligibility

Users should verify their claim eligibility and the amount they can claim using the project's off-chain services or tools, which should provide the necessary merkle root index, cumulative amount, and Merkle proof required for the claim.
