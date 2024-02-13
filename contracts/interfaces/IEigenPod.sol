// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

library Endian {
    /**
     * @notice Converts a little endian-formatted uint64 to a big endian-formatted uint64
     * @param lenum little endian-formatted uint64 input, provided as 'bytes32' type
     * @return n The big endian-formatted uint64
     * @dev Note that the input is formatted as a 'bytes32' type (i.e. 256 bits), but it is immediately truncated to a
     * uint64 (i.e. 64 bits)
     * through a right-shift/shr operation.
     */
    function fromLittleEndianUint64(bytes32 lenum) internal pure returns (uint64 n) {
        // the number needs to be stored in little-endian encoding (ie in bytes 0-8)
        n = uint64(uint256(lenum >> 192));
        return (n >> 56) | ((0x00FF000000000000 & n) >> 40) | ((0x0000FF0000000000 & n) >> 24)
            | ((0x000000FF00000000 & n) >> 8) | ((0x00000000FF000000 & n) << 8) | ((0x0000000000FF0000 & n) << 24)
            | ((0x000000000000FF00 & n) << 40) | ((0x00000000000000FF & n) << 56);
    }
}

library BeaconChainProofs {
    struct ValidatorFieldsAndBalanceProofs {
        bytes validatorFieldsProof;
        bytes validatorBalanceProof;
        bytes32 balanceRoot;
    }

    /**
     *
     * @notice This function is parses the balanceRoot to get the uint64 balance of a validator.  During merkleization
     * of the
     * beacon state balance tree, four uint64 values (making 32 bytes) are grouped together and treated as a single leaf
     * in the merkle tree. Thus the
     * validatorIndex mod 4 is used to determine which of the four uint64 values to extract from the balanceRoot.
     * @param validatorIndex is the index of the validator being proven for.
     * @param balanceRoot is the combination of 4 validator balances being proven for.
     * @return The validator's balance, in Gwei
     */
    function getBalanceFromBalanceRoot(uint40 validatorIndex, bytes32 balanceRoot) internal pure returns (uint64) {
        uint256 bitShiftAmount = (validatorIndex % 4) * 64;
        bytes32 validatorBalanceLittleEndian = bytes32((uint256(balanceRoot) << bitShiftAmount));
        uint64 validatorBalance = Endian.fromLittleEndianUint64(validatorBalanceLittleEndian);
        return validatorBalance;
    }
}

interface IBeaconDeposit {
    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);
}

interface IEigenPod {
    /// @notice This is the beacon chain deposit contract
    function ethPOS() external returns (IBeaconDeposit);

    /// @return delayedWithdrawalRouter address of eigenlayer delayedWithdrawalRouter,
    /// which does book keeping of delayed withdrawls
    function delayedWithdrawalRouter() external returns (address);

    /// @notice Called by the pod owner to withdraw the balance of the pod when `hasRestaked` is set to false
    function withdrawBeforeRestaking() external;

    /**
     * @notice This function verifies that the withdrawal credentials of the podOwner are pointed to
     * this contract. It also verifies the current (not effective) balance  of the validator.  It verifies the provided
     * proof of the ETH validator against the beacon chain state
     * root, marks the validator as 'active' in EigenLayer, and credits the restaked ETH in Eigenlayer.
     * @param oracleBlockNumber is the Beacon Chain blockNumber whose state root the `proof` will be proven against.
     * @param validatorIndex is the index of the validator being proven, refer to consensus specs
     * @param proofs is the bytes that prove the ETH validator's balance and withdrawal credentials against a beacon
     * chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentialsAndBalance(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    )
        external;
}
