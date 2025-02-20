// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IFeeReceiver } from "./interfaces/IFeeReceiver.sol";

/// @title FeeReceiver
/// @notice Recieves Mev/Execution-layer rewards
/// @dev also known as RewardReciever Contract in LRTConstants.sol
contract FeeReceiver is IFeeReceiver, Initializable, AccessControlUpgradeable {
    address public _legacyProtocolTreasury;
    address public depositPool;
    uint256 public _legacyProtocolFeePercentInBPS;

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

        _legacyProtocolTreasury = _protocolTreasury;
        depositPool = _depositPool;
        _legacyProtocolFeePercentInBPS = _protocolFeePercentInBPS;

        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(LRTConstants.MANAGER, manager);
    }

    /// @dev fallback to receive funds
    receive() external payable { }

    /// @dev send all rewards to deposit pool
    function sendFunds() external {
        uint256 balance = address(this).balance;
        ILRTDepositPool(depositPool).receiveFromRewardReceiver{ value: balance }();

        emit MevRewardsAddedToTVL(balance);
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set the deposit pool
    /// @param _depositPool Address of the deposit pool
    function setDepositPool(address _depositPool) external onlyRole(LRTConstants.MANAGER) {
        if (_depositPool == address(0)) revert InvalidEmptyValue();

        depositPool = _depositPool;
    }
}
