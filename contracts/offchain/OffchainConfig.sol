// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title OffchainConfig
 * @dev Contract for managing offchain configuration with role-based access control
 */
contract OffchainConfig is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    // Custom errors
    error NotAuthorizedUser();
    error OnlyManagerCanCall();
    error BufferAmountExceedsGlobalLimit();
    error BufferAmountExceedsAssetLimit();
    error InvalidStEthAddress();
    error InvalidEthxAddress();
    error GlobalLimitMustBeGreaterThanZero();
    error InvalidManagerAddress();

    // Role definitions
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    // Predefined asset addresses
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public STETH_ADDRESS;
    address public ETHX_ADDRESS;

    // Events
    event BufferPoolLimitSet(address indexed asset, uint256 limit);
    event BufferPoolAmountSet(address indexed asset, uint256 amount, address indexed setter);
    event GlobalLimitChanged(uint256 oldLimit, uint256 newLimit);

    // State variables
    mapping(address => uint256) public bufferPoolLimits; // Maximum buffer pool amount per asset
    mapping(address => uint256) public bufferPoolAmounts; // Current buffer pool amount per asset

    uint256 public globalLimit; // Global maximum buffer pool limit

    // Modifiers
    modifier onlyAuthorizedUser() {
        if (!hasRole(USER_ROLE, msg.sender) && !hasRole(MANAGER_ROLE, msg.sender)) {
            revert NotAuthorizedUser();
        }
        _;
    }

    modifier onlyManager() {
        if (!hasRole(MANAGER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert OnlyManagerCanCall();
        }
        _;
    }

    modifier validBufferAmount(uint256 amount, address asset) {
        if (amount > globalLimit) {
            revert BufferAmountExceedsGlobalLimit();
        }
        if (amount > bufferPoolLimits[asset]) {
            revert BufferAmountExceedsAssetLimit();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with roles and global limit
     * @param _globalLimit The maximum buffer pool amount that can be set for any asset
     * @param _initialManager Address of the initial manager
     */
    function initialize(
        uint256 _globalLimit,
        address _initialManager,
        address _stethAddress,
        address _ethxAddress
    )
        external
        initializer
    {
        if (_stethAddress == address(0)) {
            revert InvalidStEthAddress();
        }
        if (_ethxAddress == address(0)) {
            revert InvalidEthxAddress();
        }
        if (_globalLimit == 0) {
            revert GlobalLimitMustBeGreaterThanZero();
        }
        if (_initialManager == address(0)) {
            revert InvalidManagerAddress();
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        globalLimit = _globalLimit;

        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _initialManager);
        _grantRole(MANAGER_ROLE, _initialManager);

        // Grant manager role to admin
        _setRoleAdmin(MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(USER_ROLE, MANAGER_ROLE);

        STETH_ADDRESS = _stethAddress;
        ETHX_ADDRESS = _ethxAddress;
    }

    // #########################################################
    // User functions
    // #########################################################

    /**
     * @dev Set the buffer pool amount for a specific asset (only authorized users)
     * This amount represents the available liquidity for withdrawals
     * Offchain scripts will use this to manage deposit/withdrawal operations
     * @param asset Address of the asset
     * @param amount The buffer pool amount to set for this asset
     */
    function setBufferPoolAmount(
        address asset,
        uint256 amount
    )
        public
        nonReentrant
        onlyAuthorizedUser
        validBufferAmount(amount, asset)
    {
        bufferPoolAmounts[asset] = amount;

        emit BufferPoolAmountSet(asset, amount, msg.sender);
    }

    function setBufferPoolAmountETH(uint256 amount) external onlyAuthorizedUser {
        setBufferPoolAmount(ETH_ADDRESS, amount);
    }

    function setBufferPoolAmountSTETH(uint256 amount) external onlyAuthorizedUser {
        setBufferPoolAmount(STETH_ADDRESS, amount);
    }

    function setBufferPoolAmountETHX(uint256 amount) external onlyAuthorizedUser {
        setBufferPoolAmount(ETHX_ADDRESS, amount);
    }

    // #########################################################
    // Manager functions
    // #########################################################

    /**
     * @dev Set the buffer pool limit for a specific asset
     * @param asset Address of the asset
     * @param limit The maximum buffer pool amount that can be set for this asset
     */
    function setBufferPoolLimit(address asset, uint256 limit) public onlyManager {
        bufferPoolLimits[asset] = limit;

        emit BufferPoolLimitSet(asset, limit);
    }

    function setBufferPoolLimitETH(uint256 limit) external onlyManager {
        setBufferPoolLimit(ETH_ADDRESS, limit);
    }

    function setBufferPoolLimitSTETH(uint256 limit) external onlyManager {
        setBufferPoolLimit(STETH_ADDRESS, limit);
    }

    function setBufferPoolLimitETHX(uint256 limit) external onlyManager {
        setBufferPoolLimit(ETHX_ADDRESS, limit);
    }

    /**
     * @dev Change the global buffer pool limit (only manager)
     * @param newLimit The new global limit
     */
    function changeGlobalLimit(uint256 newLimit) external onlyManager {
        if (newLimit == 0) {
            revert GlobalLimitMustBeGreaterThanZero();
        }

        uint256 oldLimit = globalLimit;
        globalLimit = newLimit;

        emit GlobalLimitChanged(oldLimit, newLimit);
    }

    // #########################################################
    // Getter functions
    // #########################################################

    /**
     * @dev Get the current buffer pool amount for an asset
     * @param asset Address of the asset
     * @return The current buffer pool amount for this asset
     */
    function getBufferPoolAmount(address asset) external view returns (uint256) {
        return bufferPoolAmounts[asset];
    }

    /**
     * @dev Get the current buffer pool limit for an asset
     * @param asset Address of the asset
     * @return The current buffer pool limit for this asset
     */
    function getBufferPoolLimit(address asset) external view returns (uint256) {
        return bufferPoolLimits[asset];
    }

    /**
     * @dev Check if an address is an authorized user (has USER_ROLE or MANAGER_ROLE)
     * @param user Address to check
     * @return True if the address is an authorized user
     */
    function isAuthorizedUser(address user) external view returns (bool) {
        return hasRole(USER_ROLE, user) || hasRole(MANAGER_ROLE, user);
    }
}
