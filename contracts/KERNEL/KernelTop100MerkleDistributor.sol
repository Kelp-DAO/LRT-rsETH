// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    MerkleProofUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title IKernelDepositPool
 * @notice Interface for the KernelDepositPool contract
 */
interface IKernelDepositPool {
    /**
     * @notice Allows a user to stake tokens on behalf of another user
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

    /// @notice Error message for an invalid merkle proof
    error InvalidMerkleProof();

    /// @notice Error message for an invalid fee in basis points
    error InvalidFeeInBPS();

    /// @notice Error message for when the vesting has already started
    error VestingAlreadyStarted();

    /// @notice Error message for when the vesting start timestamp is in the past
    error VestingStartInThePast();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a user claims their tokens
     * @param account The address of the user
     * @param amount The amount of tokens claimed
     */
    event Claimed(address account, uint256 amount);

    /**
     * @notice Event emitted when a user claims their tokens and stakes them in the KernelDepositPool contract
     * @param account The address of the user
     * @param amount The amount of tokens claimed and staked in the KernelDepositPool contract
     */
    event ClaimedAndStaked(address account, uint256 amount);

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
     * @notice Event emitted when the vesting start timestamp is set
     * @param vestingStartTimestamp The vesting start timestamp
     */
    event VestingStartTimestampSet(uint256 vestingStartTimestamp);

    /**
     * @notice Event emitted when tokens are withdrawn by the owner
     * @param token The address of the token
     * @param amount The amount of tokens withdrawn
     * @param recipient The address of the recipient
     */
    event TokensWithdrawn(address token, uint256 amount, address recipient);
}

/**
 * @title KernelTop100MerkleDistributor
 * @notice A refactored contract that distributes KERNEL tokens to users based on a merkle root
 * and allows users to claim their tokens gradually over a vesting period and optionally
 * stakes them in the KernelDepositPool contract.
 */
contract KernelTop100MerkleDistributor is
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

    /// @notice The vesting duration in seconds (30 days)
    uint256 public constant VESTING_DURATION = 30 days;

    /// @notice The KERNEL token distributed by this contract
    IERC20 public kernel;

    /// @notice The address of the protocol treasury
    address public protocolTreasury;

    /// @notice The fee in basis points
    uint256 public feeInBPS;

    /// @notice The KernelDepositPool contract address
    IKernelDepositPool public kernelDepositPool;

    /// @notice The merkle root
    bytes32 public merkleRoot;

    /// @notice The timestamp when vesting begins
    uint256 public vestingStartTimestamp;

    /**
     * @notice The UserClaim struct
     * @param lastClaimTimestamp The timestamp of the last claim
     * @param amountClaimed The total amount claimed so far
     */
    struct UserClaim {
        uint256 lastClaimTimestamp;
        uint256 amountClaimed;
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
     * @notice Initializes the KernelTop100MerkleDistributor contract
     * @param _kernel The address of the KERNEL token distributed by this contract
     * @param _kernelDepositPool The address of the KernelDepositPool contract
     * @param _protocolTreasury The address of the protocol treasury
     * @param _feeInBPS The fee in basis points
     * @param _merkleRoot The merkle root for verification
     */
    function initialize(
        address _kernel,
        address _kernelDepositPool,
        address _protocolTreasury,
        uint256 _feeInBPS,
        uint256 _vestingStartTimestamp,
        bytes32 _merkleRoot
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

        if (_merkleRoot == bytes32(0)) {
            revert ZeroValueProvided();
        }

        if (_vestingStartTimestamp == 0) {
            revert ZeroValueProvided();
        }

        if (_vestingStartTimestamp <= block.timestamp) {
            revert VestingStartInThePast();
        }

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        kernel = IERC20(_kernel);
        kernelDepositPool = IKernelDepositPool(_kernelDepositPool);
        protocolTreasury = _protocolTreasury;
        feeInBPS = _feeInBPS;
        merkleRoot = _merkleRoot;
        vestingStartTimestamp = _vestingStartTimestamp;

        // Approve the KernelDepositPool contract to spend KERNEL tokens
        kernel.forceApprove(_kernelDepositPool, type(uint256).max);

        emit VestingStartTimestampSet(vestingStartTimestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the amount of unclaimed vested tokens for a user
     * @param user The address of the user
     * @param userTotalClaimableAmount The amount eligible to be claimed
     * @return The amount of unclaimed vested tokens
     */
    function _getUnclaimedVestedAmount(address user, uint256 userTotalClaimableAmount) internal view returns (uint256) {
        UserClaim storage userClaim = userClaims[user];

        // If user has claimed everything, return 0
        if (userClaim.amountClaimed >= userTotalClaimableAmount) {
            return 0;
        }

        // Calculate vesting end time
        uint256 vestingEndTime = vestingStartTimestamp + VESTING_DURATION;

        // Calculate start and end times for the period
        uint256 startTime = userClaim.lastClaimTimestamp > 0 ? userClaim.lastClaimTimestamp : vestingStartTimestamp;

        // Cap current time at vesting end time
        uint256 currentTime = block.timestamp;
        if (currentTime > vestingEndTime) {
            currentTime = vestingEndTime;
        }

        // If current time is before start time or vesting hasn't started yet, nothing to claim
        if (currentTime <= startTime || currentTime <= vestingStartTimestamp) {
            return 0;
        }

        // Calculate total vested amount based on time elapsed since vesting start
        uint256 totalElapsedTime = currentTime - vestingStartTimestamp;
        uint256 totalVestedAmount = (userTotalClaimableAmount * totalElapsedTime) / VESTING_DURATION;

        // Cap at total amount
        if (totalVestedAmount > userTotalClaimableAmount) {
            totalVestedAmount = userTotalClaimableAmount;
        }

        // Calculate unclaimed amount
        uint256 unclaimedAmount = totalVestedAmount - userClaim.amountClaimed;

        return unclaimedAmount;
    }

    /**
     * @notice Verifies the merkle proof and updates user claim data
     * @param user The address of the user
     * @param amount The amount eligible to be claimed
     * @param merkleProof The merkle proof to verify
     */
    function _verifyClaimProof(address user, uint256 amount, bytes32[] calldata merkleProof) internal view {
        UtilLib.checkNonZeroAddress(user);

        if (merkleRoot == bytes32(0)) {
            revert ZeroValueProvided();
        }

        if (amount == 0) {
            revert ZeroValueProvided();
        }

        // Verify the merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(user, amount));
        bool isValid = MerkleProofUpgradeable.verify(merkleProof, merkleRoot, leaf);

        if (!isValid) {
            revert InvalidMerkleProof();
        }
    }

    /*//////////////////////////////////////////////////////////////
                            USER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims tokens based on merkle proof verification and vesting schedule
     * @param amount The amount eligible to be claimed
     * @param merkleProof The merkle proof to verify
     */
    function claim(uint256 amount, bytes32[] calldata merkleProof) external nonReentrant whenNotPaused {
        address user = msg.sender;

        // Verify merkle proof and update user claim data
        _verifyClaimProof(user, amount, merkleProof);

        // Get claimable amount
        uint256 claimableAmount = _getUnclaimedVestedAmount(user, amount);

        if (claimableAmount == 0) {
            revert NoTokensToClaim();
        }

        // Update user claim data
        userClaims[user].lastClaimTimestamp = block.timestamp;
        userClaims[user].amountClaimed += claimableAmount;

        // Calculate fee
        uint256 fee = (claimableAmount * feeInBPS) / FEE_DENOMINATOR;
        uint256 amountToSend = claimableAmount - fee;

        // Transfer tokens
        if (fee > 0) {
            kernel.safeTransfer(protocolTreasury, fee);
        }
        kernel.safeTransfer(user, amountToSend);

        emit Claimed(user, amountToSend);
    }

    /**
     * @notice Claims tokens and stakes them in the KernelDepositPool contract
     * @param amount The amount eligible to be claimed
     * @param merkleProof The merkle proof to verify
     */
    function claimAndStake(uint256 amount, bytes32[] calldata merkleProof) external nonReentrant whenNotPaused {
        address user = msg.sender;

        // Verify merkle proof and update user claim data
        _verifyClaimProof(user, amount, merkleProof);

        // Get claimable amount
        uint256 claimableAmount = _getUnclaimedVestedAmount(user, amount);

        if (claimableAmount == 0) {
            revert NoTokensToClaim();
        }

        // Update user claim data
        userClaims[user].lastClaimTimestamp = block.timestamp;
        userClaims[user].amountClaimed += claimableAmount;

        // Calculate fee
        uint256 fee = (claimableAmount * feeInBPS) / FEE_DENOMINATOR;
        uint256 amountToStake = claimableAmount - fee;

        // Transfer fee and stake tokens
        if (fee > 0) {
            kernel.safeTransfer(protocolTreasury, fee);
        }

        kernelDepositPool.stakeFor(user, amountToStake);

        emit ClaimedAndStaked(user, amountToStake);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Public function to get the claimable amount for a user
     * @param user The address of the user
     * @param amount The amount eligible to be claimed
     * @return The amount of tokens that can be claimed
     */
    function getClaimableAmount(address user, uint256 amount) external view returns (uint256) {
        return _getUnclaimedVestedAmount(user, amount);
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

        // Revoke old approval and set new one
        kernel.forceApprove(oldKernelDepositPool, 0);
        kernel.forceApprove(_kernelDepositPool, type(uint256).max);

        kernelDepositPool = IKernelDepositPool(_kernelDepositPool);

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
     * @notice Sets the vesting start timestamp
     * @param _vestingStartTimestamp The new vesting start timestamp
     */
    function setVestingStartTimestamp(uint256 _vestingStartTimestamp) external onlyOwner {
        if (_vestingStartTimestamp == 0) {
            revert ZeroValueProvided();
        }

        if (vestingStartTimestamp > 0 && block.timestamp >= vestingStartTimestamp) {
            revert VestingAlreadyStarted();
        }

        if (_vestingStartTimestamp <= block.timestamp) {
            revert VestingStartInThePast();
        }

        vestingStartTimestamp = _vestingStartTimestamp;
        emit VestingStartTimestampSet(vestingStartTimestamp);
    }

    /**
     * @notice Allows the owner to withdraw tokens from the contract
     * @param _token The token to withdraw
     * @param _amount The amount to withdraw
     * @param _recipient The recipient of the tokens
     */
    function withdrawTokens(address _token, uint256 _amount, address _recipient) external onlyOwner {
        UtilLib.checkNonZeroAddress(_token);
        UtilLib.checkNonZeroAddress(_recipient);

        if (_amount == 0) {
            revert ZeroValueProvided();
        }

        IERC20(_token).safeTransfer(_recipient, _amount);

        emit TokensWithdrawn(_token, _amount, _recipient);
    }

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }
}
