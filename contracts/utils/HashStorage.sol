// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title HashStorage
 * @notice A contract to store and manage withdrawal transaction hashes from L2 to L1
 */
contract HashStorage is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice Description to identify the purpose of this contract
    string public description;

    /// @notice Unclaimed withdrawal tx hashes
    bytes32[] public withdrawalTxHashes;

    /// @notice A mapping to check if a withdrawal transaction hash has been claimed
    mapping(bytes32 txHash => bool isClaimed) public claimedWithdrawals;

    /// @notice Custom errors
    error DuplicateHash();
    error HashAlreadyClaimed();
    error InvalidHash();
    error NoWithdrawals();
    error EmptyDescription();

    /// @notice Events
    event WithdrawalAdded(bytes32 indexed txHash);
    event WithdrawalClaimed(bytes32 indexed txHash);
    event DescriptionUpdated(string description);

    /**
     * @notice Constructor for the HashStorage contract
     * @param admin The address of the admin
     * @param operator The address of the operator
     *  @param _description The description of the contract
     */
    constructor(address admin, address operator, string memory _description) {
        UtilLib.checkNonZeroAddress(admin);
        UtilLib.checkNonZeroAddress(operator);

        if (bytes(_description).length == 0) {
            revert EmptyDescription();
        }

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(OPERATOR_ROLE, admin);
        _setupRole(OPERATOR_ROLE, operator);

        description = _description;

        emit DescriptionUpdated(_description);
    }

    /**
     * @notice Returns the array of all currently stored withdrawal transaction hashes
     * @return The array of withdrawal transaction hashes
     */
    function getWithdrawalTxHashes() external view returns (bytes32[] memory) {
        return withdrawalTxHashes;
    }

    /**
     * @notice Adds a withdrawal transaction hash to the storage
     * @param txHash The hash of the withdrawal transaction
     */
    function addWithdrawal(bytes32 txHash) external onlyRole(OPERATOR_ROLE) {
        if (txHash == bytes32(0)) {
            revert InvalidHash();
        }

        if (claimedWithdrawals[txHash]) {
            revert HashAlreadyClaimed();
        }

        uint256 length = withdrawalTxHashes.length;

        for (uint256 i = 0; i < length; i++) {
            if (withdrawalTxHashes[i] == txHash) {
                revert DuplicateHash();
            }
        }

        claimedWithdrawals[txHash] = false;
        withdrawalTxHashes.push(txHash);

        emit WithdrawalAdded(txHash);
    }

    /**
     * @notice Marks a withdrawal transaction hash as claimed
     * @param txHash The hash of the withdrawal transaction
     */
    function setWithdrawalClaimed(bytes32 txHash) external onlyRole(OPERATOR_ROLE) {
        if (txHash == bytes32(0)) {
            revert InvalidHash();
        }

        if (withdrawalTxHashes.length == 0) {
            revert NoWithdrawals();
        }

        if (claimedWithdrawals[txHash]) {
            revert HashAlreadyClaimed();
        }

        uint256 length = withdrawalTxHashes.length;
        bool found = false;

        for (uint256 i = 0; i < length; i++) {
            if (withdrawalTxHashes[i] == txHash) {
                found = true;
                withdrawalTxHashes[i] = withdrawalTxHashes[withdrawalTxHashes.length - 1];
                withdrawalTxHashes.pop();
                break;
            }
        }

        if (!found) {
            revert InvalidHash();
        }

        claimedWithdrawals[txHash] = true;

        emit WithdrawalClaimed(txHash);
    }

    /**
     * @notice Updates the description of the contract
     * @param _description The new description of the contract
     */
    function updateDescription(string calldata _description) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (bytes(_description).length == 0) {
            revert EmptyDescription();
        }

        description = _description;

        emit DescriptionUpdated(_description);
    }
}
