// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { MerkleProofUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

interface IBlastPoints {
    function configurePointsOperator(address operator) external;
    function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}

interface IMerkleBlastPointsDistributor {
    error ZeroValueProvided();
    error NoPointsToClaim();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error InvalidIndex();

    /// @dev Returns true if the index has been marked claimed.
    /// @param index The index of the claim.
    /// @param account The address to check if the claim is claimed.
    function isClaimed(uint256 index, address account) external view returns (bool);

    /// @dev Claim the given amount of points to the given address. Reverts if the inputs are invalid.
    /// @param index The index of the claim.
    /// @param account The address to send the points to.
    /// @param cumulativeBlastPointAmount The cumulative amount of Blast Points of the claim.
    /// @param cumulativeBlastGoldAmount The cumulative amount of Blast Gold of the claim.
    /// @param merkleProof The merkle proof to verify the claim.
    function claim(
        uint256 index,
        address account,
        uint256 cumulativeBlastPointAmount,
        uint256 cumulativeBlastGoldAmount,
        bytes32[] calldata merkleProof
    )
        external;

    event Claimed(uint256 index, address account, uint256 blastPoints, uint256 blastGold);
    event MerkleRootSet(uint256 index, bytes32 currentMerkleRoot);
}

/// @title MerkleBlastPointsDistributor
/// @notice It is used to distribute Blast Points to users based on a merkle root.
contract MerkleBlastPointsDistributor is IMerkleBlastPointsDistributor, OwnableUpgradeable, PausableUpgradeable {
    uint256 public currentMerkleRootIndex;
    bytes32 public currentMerkleRoot;

    address public blastPointAddress;

    uint256 public currentIndex;

    struct UserClaim {
        uint256 lastClaimedIndex;
        uint256 cumulativeBlastPointAmount;
        uint256 cumulativeBlastGoldAmount;
    }

    mapping(address user => UserClaim userClaim) public userClaims;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    function initialize(address _blastPointAddress, address _pointsOperator) public initializer {
        __Ownable_init();
        __Pausable_init();

        blastPointAddress = _blastPointAddress;
        IBlastPoints(blastPointAddress).configurePointsOperator(_pointsOperator);
    }

    /// @inheritdoc IMerkleBlastPointsDistributor
    function isClaimed(uint256 index, address account) public view override returns (bool) {
        if (index == 0) revert ZeroValueProvided();

        return userClaims[account].lastClaimedIndex >= index;
    }

    /// @inheritdoc IMerkleBlastPointsDistributor
    function claim(
        uint256 index,
        address account,
        uint256 cumulativeBlastPointAmount,
        uint256 cumulativeBlastGoldAmount,
        bytes32[] calldata merkleProof
    )
        external
        override
        whenNotPaused
    {
        if (currentMerkleRoot == bytes32(0)) {
            revert ZeroValueProvided();
        }

        if (index == 0 || index > currentIndex) {
            revert InvalidIndex();
        }

        if (isClaimed(index, account)) {
            revert AlreadyClaimed();
        }

        // Verify the merkle proof.
        bytes32 node =
            keccak256(abi.encodePacked(index, account, cumulativeBlastPointAmount, cumulativeBlastGoldAmount));
        if (!MerkleProofUpgradeable.verify(merkleProof, currentMerkleRoot, node)) {
            revert InvalidMerkleProof();
        }

        // Calculate the claimable amount
        uint256 claimableBlastPoints = cumulativeBlastPointAmount - userClaims[account].cumulativeBlastPointAmount;
        uint256 claimableBlastGold = cumulativeBlastGoldAmount - userClaims[account].cumulativeBlastGoldAmount;

        // Ensure there is something to claim
        if (claimableBlastPoints == 0 && claimableBlastGold == 0) {
            revert NoPointsToClaim();
        }

        // Update user claim info
        userClaims[account].lastClaimedIndex = index;
        userClaims[account].cumulativeBlastPointAmount = cumulativeBlastPointAmount;
        userClaims[account].cumulativeBlastGoldAmount = cumulativeBlastGoldAmount;

        emit Claimed(index, account, claimableBlastPoints, claimableBlastGold);
    }

    /*//////////////////////////////////////////////////////////////
                            Admin FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Set the merkle root for the given index.
    /// @dev only called by the owner.
    /// @param _merkleRootToSet The merkle root to set.
    function setMerkleRoot(bytes32 _merkleRootToSet) external onlyOwner {
        if (_merkleRootToSet == bytes32(0)) {
            revert ZeroValueProvided();
        }

        currentMerkleRoot = _merkleRootToSet;

        currentMerkleRootIndex++;
        currentIndex++;

        emit MerkleRootSet(currentMerkleRootIndex, currentMerkleRoot);
    }

    /// @dev Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @dev set points operator on behald of contract.
    /// @dev If the caller, in this case owner,  is not the operator it will revert
    /// @param contractAddress the contract you’d like to change the points operator for
    /// @param operator the address of the new points operator
    function setPointsOperatorOnBehalf(address contractAddress, address operator) external onlyOwner {
        IBlastPoints(blastPointAddress).configurePointsOperatorOnBehalf(contractAddress, operator);
    }

    /// @dev Get the cumulative Blast Points balance of a user.
    /// @param account The address of the user.
    function getCumulativeBlastPoints(address account) external view returns (uint256) {
        return userClaims[account].cumulativeBlastPointAmount;
    }

    /// @dev Get the cumulative Blast Gold balance of a user.
    /// @param account The address of the user.
    function getCumulativeBlastGold(address account) external view returns (uint256) {
        return userClaims[account].cumulativeBlastGoldAmount;
    }
}
