// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { MerkleProofUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IMerkleDistributor {
    error ZeroValueProvided();
    error NoTokensToClaim();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error TransferFailed();
    error InvalidIndex();

    /// @dev returns the address of the token distributed by this contract.
    function token() external view returns (address);

    /// @dev Returns true if the index has been marked claimed.
    /// @param index The index of the claim.
    /// @param account The address to check if the claim is claimed.
    function isClaimed(uint256 index, address account) external view returns (bool);

    /// @dev claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    /// @param index The index of the claim.
    /// @param account The address to send the token to.
    /// @param cumulativeAmount The cumulative amount of the claim.
    /// @param merkleProof The merkle proof to verify the claim.
    function claim(uint256 index, address account, uint256 cumulativeAmount, bytes32[] calldata merkleProof) external;

    event Claimed(uint256 index, address account, uint256 amount);
    event MerkleRootSet(uint256 index, bytes32 currentMerkleRoot);
}

/// @title MerkleDistributor
/// @notice Generice Merkle distributor contract. It is used to distribute tokens to users based on a merkle root.
contract MerkleDistributor is IMerkleDistributor, OwnableUpgradeable, PausableUpgradeable {
    address public override token;
    address public protocolTreasury;
    uint256 public feeInBPS;

    uint256 public currentMerkleRootIndex;
    bytes32 public currentMerkleRoot;

    uint256 public currentIndex;

    struct UserClaim {
        uint256 lastClaimedIndex;
        uint256 cumulativeAmount;
    }

    mapping(address user => UserClaim userClaim) public userClaims;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    function initialize(address token_, address _protocolTreasury, uint256 _feeInBPS) public initializer {
        if (token_ == address(0) || _protocolTreasury == address(0)) {
            revert ZeroValueProvided();
        }

        __Ownable_init();
        __Pausable_init();

        token = token_;
        protocolTreasury = _protocolTreasury;
        feeInBPS = _feeInBPS;
    }

    /// @inheritdoc IMerkleDistributor
    function isClaimed(uint256 index, address account) public view override returns (bool) {
        if (index == 0) revert ZeroValueProvided();

        return userClaims[account].lastClaimedIndex >= index;
    }

    /// @inheritdoc IMerkleDistributor
    function claim(
        uint256 index,
        address account,
        uint256 cumulativeAmount,
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
        bytes32 node = keccak256(abi.encodePacked(index, account, cumulativeAmount));
        if (!MerkleProofUpgradeable.verify(merkleProof, currentMerkleRoot, node)) {
            revert InvalidMerkleProof();
        }

        // Calculate the claimable amount
        uint256 claimableAmount = cumulativeAmount - userClaims[account].cumulativeAmount;

        // Ensure there is something to claim
        if (claimableAmount == 0) {
            revert NoTokensToClaim();
        }

        // Update user claim info, and send the token.
        userClaims[account].lastClaimedIndex = index;
        userClaims[account].cumulativeAmount = cumulativeAmount;

        // Send the claimable amount to the user - deducting the fee
        uint256 fee = (claimableAmount * feeInBPS) / 10_000;
        uint256 amountToSend = claimableAmount - fee;

        if (!IERC20(token).transfer(account, amountToSend)) {
            revert TransferFailed();
        }

        // Send the fee to the protocol treasury
        if (!IERC20(token).transfer(protocolTreasury, fee)) {
            revert TransferFailed();
        }

        emit Claimed(index, account, claimableAmount);
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

    /// @dev Set the protocol treasury address.
    /// @dev only called by the owner.
    /// @param _protocolTreasury The address of the protocol treasury.
    function setProtocolTreasury(address _protocolTreasury) external onlyOwner {
        if (_protocolTreasury == address(0)) {
            revert ZeroValueProvided();
        }

        protocolTreasury = _protocolTreasury;
    }

    /// @dev Set the token address.
    /// @dev only called by the owner.
    /// @param _token The address of the token.
    function setToken(address _token) external onlyOwner {
        if (_token == address(0)) {
            revert ZeroValueProvided();
        }

        token = _token;
    }

    /// @dev Set the fee in BPS.
    /// @dev only called by the owner.
    /// @param _feeInBPS The fee in BPS.
    function setFeeInBPS(uint256 _feeInBPS) external onlyOwner {
        feeInBPS = _feeInBPS;
    }

    /// @dev Pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}
