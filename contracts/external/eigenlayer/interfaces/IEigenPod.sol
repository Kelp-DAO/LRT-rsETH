// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { BeaconChainProofs } from "../libraries/BeaconChainProofs.sol";

interface IBeaconDeposit {
    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);
}

interface IEigenPod {
    enum VALIDATOR_STATUS {
        INACTIVE, // doesnt exist
        ACTIVE, // staked on ethpos and withdrawal credentials are pointed to the EigenPod
        WITHDRAWN // withdrawn from the Beacon Chain

    }

    struct ValidatorInfo {
        // index of the validator in the beacon chain
        uint64 validatorIndex;
        // amount of beacon chain ETH restaked on EigenLayer in gwei
        uint64 restakedBalanceGwei;
        //timestamp of the validator's most recent balance update
        uint64 mostRecentBalanceUpdateTimestamp;
        // status of the validator
        VALIDATOR_STATUS status;
    }
    /// @notice This is the beacon chain deposit contract

    function ethPOS() external view returns (IBeaconDeposit);

    /// @return delayedWithdrawalRouter address of eigenlayer delayedWithdrawalRouter,
    /// which does book keeping of delayed withdrawls
    function delayedWithdrawalRouter() external view returns (address);

    /// @notice an indicator of whether or not the podOwner has ever "fully restaked" by successfully calling
    /// `verifyCorrectWithdrawalCredentials`.
    function hasRestaked() external view returns (bool);

    /// @notice Called by the pod owner to withdraw the balance of the pod when `hasRestaked` is set to false
    function withdrawBeforeRestaking() external;

    /**
     * @notice Called by the pod owner to activate restaking by withdrawing
     * all existing ETH from the pod and preventing further withdrawals via
     * "withdrawBeforeRestaking()"
     */
    function activateRestaking() external;

    /**
     * @notice This function verifies that the withdrawal credentials of validator(s) owned by the podOwner are pointed
     * to
     * this contract. It also verifies the effective balance  of the validator.  It verifies the provided proof of the
     * ETH validator against the beacon chain state
     * root, marks the validator as 'active' in EigenLayer, and credits the restaked ETH in Eigenlayer.
     * @param oracleTimestamp is the Beacon Chain timestamp whose state root the `proof` will be proven against.
     * @param validatorIndices is the list of indices of the validators being proven, refer to consensus specs
     * @param withdrawalCredentialProofs is an array of proofs, where each proof proves each ETH validator's balance and
     * withdrawal credentials
     * against a beacon chain state root
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * for details: https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata withdrawalCredentialProofs,
        bytes32[][] calldata validatorFields
    )
        external;

    /**
     * @notice This function records an update (either increase or decrease) in the pod's balance in the
     * StrategyManager.
     *            It also verifies a merkle proof of the validator's current beacon chain balance.
     * @param oracleTimestamp The oracleTimestamp whose state root the `proof` will be proven against.
     *        Must be within `VERIFY_BALANCE_UPDATE_WINDOW_SECONDS` of the current block.
     * @param validatorIndices is the list of indices of the validators being proven, refer to consensus specs
     * @param validatorFieldsProofs proofs against the `beaconStateRoot` for each validator in `validatorFields`
     * @param validatorFields are the fields of the "Validator Container", refer to consensus specs
     * @dev For more details on the Beacon Chain spec, see:
     * https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/beacon-chain.md#validator
     */
    function verifyBalanceUpdates(
        uint64 oracleTimestamp,
        uint40[] calldata validatorIndices,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    )
        external;

    /**
     * @notice This function records full and partial withdrawals on behalf of one of the Ethereum validators for this
     * EigenPod
     * @param oracleTimestamp is the timestamp of the oracle slot that the withdrawal is being proven against
     * @param withdrawalProofs is the information needed to check the veracity of the block numbers and withdrawals
     * being proven
     * @param validatorFieldsProofs is the proof of the validator's fields' in the validator tree
     * @param withdrawalFields are the fields of the withdrawals being proven
     * @param validatorFields are the fields of the validators being proven
     */
    function verifyAndProcessWithdrawals(
        uint64 oracleTimestamp,
        BeaconChainProofs.StateRootProof calldata stateRootProof,
        BeaconChainProofs.WithdrawalProof[] calldata withdrawalProofs,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields,
        bytes32[][] calldata withdrawalFields
    )
        external;

    function mostRecentWithdrawalTimestamp() external view returns (uint64);

    function withdrawableRestakedExecutionLayerGwei() external view returns (uint64);

    function validatorPubkeyHashToInfo(bytes32) external view returns (ValidatorInfo memory);
}
