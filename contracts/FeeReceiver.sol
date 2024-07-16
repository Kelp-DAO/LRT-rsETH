// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IFeeReceiver } from "./interfaces/IFeeReceiver.sol";

/// @title FeeReceiver
/// @notice Recieves rewards and distributes it
/// @dev also known as RewardReciever Contract in LRTContansts
contract FeeReceiver is IFeeReceiver, Initializable, AccessControlUpgradeable {
    address public protocolTreasury;
    address public depositPool;
    uint256 public protocolFeePercentInBPS;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _protocolTreasury,
        address _depositPool,
        uint256 _protocolFeePercentInBPS,
        address admin,
        address manager
    )
        public
        initializer
    {
        if (
            _protocolTreasury == address(0) || _depositPool == address(0) || _protocolFeePercentInBPS == 0
                || admin == address(0) || manager == address(0)
        ) {
            revert InvalidEmptyValue();
        }

        protocolTreasury = _protocolTreasury;
        depositPool = _depositPool;
        protocolFeePercentInBPS = _protocolFeePercentInBPS;

        __AccessControl_init();

        // manager is both the default admin and the MANAGER role
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(LRTConstants.MANAGER, manager);
    }

    /// @dev fallback to receive funds
    receive() external payable { }

    /// @dev receive from NodeDelegator
    function receiveFromNodeDelegator() external payable { }

    /// @dev send percentage of the contract's balance to the fee receiver
    function sendFunds() external {
        uint256 balance = address(this).balance;
        uint256 amountToSendToProtocolTreasury = (balance * protocolFeePercentInBPS) / 10_000;

        (bool success,) = protocolTreasury.call{ value: amountToSendToProtocolTreasury }("");
        require(success, "FeeReceiver: failed to send to protocol treasury");

        // send the remaining balance to the deposit pool
        uint256 remainingAmount = address(this).balance;
        ILRTDepositPool(depositPool).receiveFromRewardReceiver{ value: remainingAmount }();
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set the fee receiver
    /// @param _protocolTreasury Address of the fee receiver
    function setProtocolTreasury(address _protocolTreasury) external onlyRole(LRTConstants.MANAGER) {
        if (_protocolTreasury == address(0)) revert InvalidEmptyValue();

        protocolTreasury = _protocolTreasury;
    }

    /// @dev Set the deposit pool
    /// @param _depositPool Address of the deposit pool
    function setDepositPool(address _depositPool) external onlyRole(LRTConstants.MANAGER) {
        if (_depositPool == address(0)) revert InvalidEmptyValue();

        depositPool = _depositPool;
    }

    /// @dev Set the percentage to send
    /// @param _protocolFeePercentInBPS Percentage to send
    function setProtocolFeePercentage(uint256 _protocolFeePercentInBPS) external onlyRole(LRTConstants.MANAGER) {
        if (_protocolFeePercentInBPS == 0) revert InvalidEmptyValue();
        protocolFeePercentInBPS = _protocolFeePercentInBPS;
    }
}
