// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { MerkleProofUpgradeable } from
    "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title IKernelDepositPool
 * @notice Interface for the KernelDepositPool contract
 */
interface IKernelDepositPool {
    /**
     * @notice Allows a user to stake tokens on behalf of another user
     * @dev Only STAKE_FOR_ROLE can call this function
     * @param _account The address of the account to stake for
     * @param _amount The amount of staking tokens to stake
     */
    function stakeFor(address _account, uint256 _amount) external;
}

interface IMerkleDistributor {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error message for a zero value provided as input (e.g. 0 for uint256 or bytes32(0) for bytes32)
    error ZeroValueProvided();

    /// @notice Error message for when there are no tokens to claim
    error NoTokensToClaim();

    /// @notice Error message for when the user has already claimed
    error AlreadyClaimed();

    /// @notice Error message for an invalid merkle proof
    error InvalidMerkleProof();

    /// @notice Error message for an invalid index
    error InvalidIndex();

    /// @notice Error message for an invalid fee in basis points
    error InvalidFeeInBPS();

    /// @notice Error message for an unauthorized user action
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a user claims their tokens
     * @param index The index of the claim
     * @param account The address of the user
     * @param amount The amount of tokens claimed
     */
    event Claimed(uint256 index, address account, uint256 amount);

    /**
     * @notice Event emitted when a user claims their tokens and stakes them in the KernelDepositPool contract
     * @param index The index of the claim
     * @param account The address of the user
     * @param amount The amount of tokens claimed and staked in the KernelDepositPool contract
     */
    event ClaimedAndStaked(uint256 index, address account, uint256 amount);

    /**
     * @notice Event emitted when the KernelDepositPool contract address is updated
     * @param kernelDepositPool The address of the new KernelDepositPool contract
     */
    event KernelDepositPoolUpdated(address kernelDepositPool);

    /**
     * @notice Event emitted when the protocol treasury address is updated
     * @param protocolTreasury The address of the new protocol treasury
     */
    event ProtocolTreasuryUpdated(address protocolTreasury);

    /**
     * @notice Event emitted when the fee in basis points is updated
     * @param feeInBPS The new fee in basis points
     */
    event FeeInBPSUpdated(uint256 feeInBPS);

    /**
     * @notice Event emitted when the merkle root is set
     * @param index The index of the merkle root
     * @param currentMerkleRoot The current merkle root
     */
    event MerkleRootSet(uint256 index, bytes32 currentMerkleRoot);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the token distributed by this contract
    function token() external view returns (address);

    /**
     * @notice Returns true if the index has been marked as claimed
     * @param index The index of the claim
     * @param account The address to check for if the claim is claimed
     * @return true if the claim has been marked claimed, false otherwise
     */
    function isClaimed(uint256 index, address account) external view returns (bool);

    /**
     * @notice Claims the given amount of the token to the given address. Reverts if the inputs are invalid
     * @param index The index of the claim
     * @param account The address to send the token to
     * @param cumulativeAmount The cumulative amount of the claim
     * @param merkleProof The merkle proof to verify the claim
     */
    function claim(uint256 index, address account, uint256 cumulativeAmount, bytes32[] calldata merkleProof) external;
}

/**
 * @title KernelMerkleDistributor
 * @notice A contract that distributes KERNEL tokens to users based on a merkle root, and allows users to claim
 * their tokens and stakes them in the KernelDepositPool contract in a single transaction.
 */
contract KernelMerkleDistributor is
    IMerkleDistributor,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice The fee denominator constant used to calculate the fee
    uint256 public constant FEE_DENOMINATOR = 10_000;

    /// @notice The maximum fee in basis points that can be set by the owner (10%)
    uint256 public constant MAX_FEE_IN_BPS = 1000;

    /// @notice The KERNEL token distributed by this contract
    IERC20 public kernel;

    /// @notice The address of the protocol treasury
    address public protocolTreasury;

    /// @notice The fee in basis points
    uint256 public feeInBPS;

    /// @notice The KernelDepositPool contract address
    IKernelDepositPool public kernelDepositPool;

    /// @notice The current index of the current merkle root
    uint256 public currentMerkleRootIndex;

    /// @notice The current merkle root
    bytes32 public currentMerkleRoot;

    /// @notice The current index
    uint256 public currentIndex;

    /**
     * @notice The UserClaim struct
     * @param lastClaimedIndex The last claimed index
     * @param cumulativeAmount The cumulative amount claimed
     */
    struct UserClaim {
        uint256 lastClaimedIndex;
        uint256 cumulativeAmount;
    }

    /// @notice The user claims mapping
    mapping(address user => UserClaim userClaim) public userClaims;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the KernelMerkleDistributor contract
     * @param _kernel The address of the KERNEL token distributed by this contract
     * @param _kernelDepositPool The address of the KernelDepositPool contract
     * @param _protocolTreasury The address of the protocol treasury
     * @param _feeInBPS The fee in basis points
     */
    function initialize(
        address _kernel,
        address _kernelDepositPool,
        address _protocolTreasury,
        uint256 _feeInBPS
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(_kernel);
        UtilLib.checkNonZeroAddress(_kernelDepositPool);
        UtilLib.checkNonZeroAddress(_protocolTreasury);

        if (_feeInBPS > MAX_FEE_IN_BPS) {
            revert InvalidFeeInBPS();
        }

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        kernel = IERC20(_kernel);
        kernelDepositPool = IKernelDepositPool(_kernelDepositPool);
        protocolTreasury = _protocolTreasury;
        feeInBPS = _feeInBPS;

        // Approve the KernelDepositPool contract to spend an unlimited amount of KERNEL tokens on behalf of this
        // contract
        kernel.safeApprove(_kernelDepositPool, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMerkleDistributor
    function token() external view override returns (address) {
        return address(kernel);
    }

    /// @inheritdoc IMerkleDistributor
    function isClaimed(uint256 index, address account) public view override returns (bool) {
        if (index == 0) revert ZeroValueProvided();

        return userClaims[account].lastClaimedIndex >= index;
    }

    /*//////////////////////////////////////////////////////////////
                            USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        nonReentrant
    {
        uint256 amountToSend = _processClaim(index, account, cumulativeAmount, merkleProof);

        kernel.safeTransfer(account, amountToSend);

        emit Claimed(index, account, amountToSend);
    }

    /// @notice Claims the given amount of the tokens for a given address and automatically stakes them in the
    /// KernelDepositPool contract as part of the same transaction
    function claimAndStake(
        uint256 index,
        address account,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        external
        whenNotPaused
        nonReentrant
    {
        uint256 amountToStake = _processClaim(index, account, cumulativeAmount, merkleProof);

        IKernelDepositPool(kernelDepositPool).stakeFor(account, amountToStake);

        emit ClaimedAndStaked(index, account, amountToStake);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to process the claim and calculate the amount to claim
    function _processClaim(
        uint256 index,
        address account,
        uint256 cumulativeAmount,
        bytes32[] calldata merkleProof
    )
        internal
        returns (uint256)
    {
        UtilLib.checkNonZeroAddress(account);

        if (currentMerkleRoot == bytes32(0)) {
            revert ZeroValueProvided();
        }

        if (index == 0 || index > currentIndex) {
            revert InvalidIndex();
        }

        if (account != msg.sender) {
            revert Unauthorized();
        }

        if (isClaimed(index, account)) {
            revert AlreadyClaimed();
        }

        // Verify the merkle proof
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

        // Update user claim info
        userClaims[account].lastClaimedIndex = index;
        userClaims[account].cumulativeAmount = cumulativeAmount;

        // Calculate the fee and the amount to send
        uint256 fee = (claimableAmount * feeInBPS) / FEE_DENOMINATOR;
        uint256 amountToSend = claimableAmount - fee;

        if (fee > 0) {
            kernel.safeTransfer(protocolTreasury, fee);
        }

        return amountToSend;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the KernelDepositPool contract address
     * @param _kernelDepositPool The address of the new KernelDepositPool contract
     */
    function setKernelDepositPool(address _kernelDepositPool) external onlyOwner {
        UtilLib.checkNonZeroAddress(_kernelDepositPool);

        address oldKernelDepositPool = address(kernelDepositPool);
        kernelDepositPool = IKernelDepositPool(_kernelDepositPool);

        // Revoke the approval of the old KernelDepositPool contract to spend KERNEL tokens on behalf of this contract
        kernel.safeApprove(oldKernelDepositPool, 0);

        // Approve the KernelDepositPool contract to spend an unlimited amount of KERNEL tokens on behalf of this
        // contract
        kernel.safeApprove(_kernelDepositPool, type(uint256).max);

        emit KernelDepositPoolUpdated(_kernelDepositPool);
    }

    /**
     * @notice Sets the protocol treasury address
     * @param _protocolTreasury The address of the new protocol treasury
     */
    function setProtocolTreasury(address _protocolTreasury) external onlyOwner {
        UtilLib.checkNonZeroAddress(_protocolTreasury);

        protocolTreasury = _protocolTreasury;

        emit ProtocolTreasuryUpdated(protocolTreasury);
    }

    /**
     * @notice Sets the fee in basis points
     * @param _feeInBPS The new fee in basis points
     */
    function setFeeInBPS(uint256 _feeInBPS) external onlyOwner {
        if (_feeInBPS > MAX_FEE_IN_BPS) {
            revert InvalidFeeInBPS();
        }

        feeInBPS = _feeInBPS;

        emit FeeInBPSUpdated(feeInBPS);
    }

    /**
     * @notice Sets the new merkle root
     * @param _merkleRootToSet The new merkle root to be set
     */
    function setMerkleRoot(bytes32 _merkleRootToSet) external onlyOwner {
        if (_merkleRootToSet == bytes32(0)) {
            revert ZeroValueProvided();
        }

        currentMerkleRoot = _merkleRootToSet;

        currentMerkleRootIndex++;
        currentIndex++;

        emit MerkleRootSet(currentMerkleRootIndex, currentMerkleRoot);
    }

    /// @dev Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @dev Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}
