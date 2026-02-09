// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title IStakerGateway
 * @notice Interface for the StakerGateway contract from Kernel Protocol, which serves as the
 * main entry point of the protocol for staking and unstaking tokens.
 */
interface IStakerGateway {
    /**
     * @notice Allows users to stake assets specifying another address as beneficiary of the deposit
     * @dev Staker must provide prior approval to this contract for transfering ERC20 asset
     * @dev Only ROLE_ENABLED_TO_STAKE_FOR can call this function
     * @param asset address of the token to stake
     * @param receiver the address that will receive the deposit
     * @param amount amount to stake
     * @param referralId the referral id (if any)
     */
    function stakeFor(address asset, address receiver, uint256 amount, string calldata referralId) external;
}

/**
 * @title KernelReceiver
 * @notice This contract is responsible for being the intermediary destination of KERNEL tokens that are
 * bridged from Ethereum mainnet to the Binance Smart Chain (BSC) via LayerZero, and it’s through this
 * contract that the restaking deposits on behalf of the users are made.
 */
contract KernelReceiver is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The operator role within the contract
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice The KERNEL token contract on BSC (Binance Smart Chain)
    IERC20 public kernel;

    /// @notice Reference to the IStakerGateway contract from Kernel Protocol
    IStakerGateway public stakerGateway;

    /// @notice The last deposit ID that was staked by the operator
    uint256 public lastStakedDepositId;

    /**
     * @notice Event emitted when the operator stakes KERNEL tokens on behalf of a user
     * @param user The address of the user
     * @param amount The amount of KERNEL tokens staked
     */
    event KernelStakedFor(address indexed user, uint256 indexed amount);

    /**
     * @notice Event emitted when the StakerGateway contract address is updated
     * @param newStakerGateway The address of the new StakerGateway contract
     * @param oldStakerGateway The address of the old StakerGateway contract
     */
    event StakerGatewayUpdated(address indexed newStakerGateway, address indexed oldStakerGateway);

    /// @notice Error message for an invalid KERNEL token amount
    error InvalidKernelAmount();

    /// @notice Error message for an array with zero length
    error ZeroArrayLength();

    /// @notice Error message for an array length mismatch
    error ArrayLengthMismatch();

    /// @notice Error message for an insufficient KERNEL token balance in the contract
    error InsufficientKernelBalance();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the KernelReceiver contract
     * @param _admin The address of the admin role
     * @param _operator The address of the operator role
     * @param _kernel The address of the KERNEL token contract on BSC
     * @param _stakerGateway The address of the StakerGateway contract
     */
    function initialize(
        address _admin,
        address _operator,
        address _kernel,
        address _stakerGateway
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_operator);
        UtilLib.checkNonZeroAddress(_kernel);
        UtilLib.checkNonZeroAddress(_stakerGateway);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);

        kernel = IERC20(_kernel);
        stakerGateway = IStakerGateway(_stakerGateway);

        // Approve the StakerGateway contract to spend an unlimited amount of KERNEL tokens on behalf of this contract
        // in order to avoid the need to approve the contract every time an operator stakes KERNEL tokens on behalf of a
        // user
        kernel.forceApprove(_stakerGateway, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            Operator Actions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restakes the KERNEL tokens on behalf of the user, based on their deposit from the Ethereum mainnet
     * @param user The address of the user
     * @param amount The amount of KERNEL tokens to be restaked in the Kernel Protocol
     */
    function stakeFor(address user, uint256 amount) external nonReentrant whenNotPaused onlyRole(OPERATOR_ROLE) {
        _stakeFor(user, amount);
    }

    /**
     * @notice Restakes the KERNEL tokens on behalf of multiple users, based on their deposits from the Ethereum mainnet
     * @param users The addresses of the users
     * @param amounts The amounts of KERNEL tokens to be restaked in the Kernel Protocol
     */
    function batchStakeFor(
        address[] calldata users,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        whenNotPaused
        onlyRole(OPERATOR_ROLE)
    {
        if (users.length == 0) {
            revert ZeroArrayLength();
        }

        if (users.length != amounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < users.length; ++i) {
            _stakeFor(users[i], amounts[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Admin Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the StakerGateway contract address
     * @param _stakerGateway The address of the new StakerGateway contract
     */
    function setStakerGateway(address _stakerGateway) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_stakerGateway);

        IStakerGateway oldStakerGateway = stakerGateway;
        stakerGateway = IStakerGateway(_stakerGateway);

        // Revoke the approval of the old StakerGateway contract to spend KERNEL tokens on behalf of this contract
        kernel.forceApprove(address(oldStakerGateway), 0);

        // Approve the new StakerGateway contract to spend an unlimited amount of KERNEL tokens on behalf of this
        // contract in order to avoid the need to approve the contract every time an operator stakes KERNEL tokens on
        // behalf of a user
        kernel.forceApprove(_stakerGateway, type(uint256).max);

        emit StakerGatewayUpdated(_stakerGateway, address(oldStakerGateway));
    }

    /// @notice Pauses the contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            Internal Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to stake KERNEL tokens on behalf of a user
     * @param user The address of the user
     * @param amount The amount of KERNEL tokens to be staked
     */
    function _stakeFor(address user, uint256 amount) internal {
        UtilLib.checkNonZeroAddress(user);

        if (amount == 0) {
            revert InvalidKernelAmount();
        }

        if (kernel.balanceOf(address(this)) < amount) {
            revert InsufficientKernelBalance();
        }

        ++lastStakedDepositId;
        stakerGateway.stakeFor(address(kernel), user, amount, "");

        emit KernelStakedFor(user, amount);
    }
}
