// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { LRTConfigRoleChecker } from "./utils/LRTConfigRoleChecker.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { IPubkeyRegistry } from "./interfaces/IPubkeyRegistry.sol";

contract PubkeyRegistry is IPubkeyRegistry, LRTConfigRoleChecker, Initializable {
    error CallerNotLRTNodeDelegator();

    mapping(bytes32 pubKeyHashed => bool hasBeenUsed) public pubkeyRegistry;

    modifier onlyLRTNodeDelegator() {
        ILRTDepositPool lrtDepositPool = ILRTDepositPool(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));

        if (lrtDepositPool.isNodeDelegator(msg.sender) != 1) {
            revert CallerNotLRTNodeDelegator();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    function hasPubkey(bytes calldata pubkey) public view returns (bool) {
        return pubkeyRegistry[keccak256(pubkey)];
    }

    function addPubkey(bytes calldata pubkey) public onlyLRTNodeDelegator {
        pubkeyRegistry[keccak256(pubkey)] = true;
    }

    function addPubkeys(bytes[] calldata pubkeys) public onlyLRTManager {
        for (uint256 i = 0; i < pubkeys.length; i++) {
            pubkeyRegistry[keccak256(pubkeys[i])] = true;
        }
    }
}
