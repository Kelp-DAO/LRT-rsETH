// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { LRTConstants } from "./LRTConstants.sol";

import { ILRTConfig } from "../interfaces/ILRTConfig.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

/// @title LRTConfigRoleChecker - LRT Config Role Checker Contract
/// @notice Handles LRT config role checks
abstract contract LRTConfigRoleChecker {
    ILRTConfig public lrtConfig;

    // events
    event UpdatedLRTConfig(address indexed lrtConfig);

    // modifiers
    modifier onlyRole(bytes32 role) {
        if (!IAccessControl(address(lrtConfig)).hasRole(role, msg.sender)) {
            string memory roleStr = string(abi.encodePacked(role));
            revert ILRTConfig.CallerNotLRTConfigAllowedRole(roleStr);
        }
        _;
    }

    modifier onlyLRTManager() {
        if (!IAccessControl(address(lrtConfig)).hasRole(LRTConstants.MANAGER, msg.sender)) {
            revert ILRTConfig.CallerNotLRTConfigManager();
        }
        _;
    }

    modifier onlyLRTOperator() {
        if (!IAccessControl(address(lrtConfig)).hasRole(LRTConstants.OPERATOR_ROLE, msg.sender)) {
            revert ILRTConfig.CallerNotLRTConfigOperator();
        }
        _;
    }

    modifier onlyAssetTransferRole() {
        if (!IAccessControl(address(lrtConfig)).hasRole(LRTConstants.ASSET_TRANSFER_ROLE, msg.sender)) {
            revert ILRTConfig.CallerNotLRTConfigAssetTransferRole();
        }
        _;
    }

    modifier onlyAssetTransferOrOperatorRole() {
        if (
            !IAccessControl(address(lrtConfig)).hasRole(LRTConstants.ASSET_TRANSFER_ROLE, msg.sender)
                && !IAccessControl(address(lrtConfig)).hasRole(LRTConstants.OPERATOR_ROLE, msg.sender)
        ) {
            revert ILRTConfig.CallerNotLRTConfigOperatorOrAssetTransferRole();
        }
        _;
    }

    modifier onlyLRTAdmin() {
        if (!IAccessControl(address(lrtConfig)).hasRole(LRTConstants.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert ILRTConfig.CallerNotLRTConfigAdmin();
        }
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!lrtConfig.isSupportedAsset(asset)) {
            revert ILRTConfig.AssetNotSupported();
        }
        _;
    }

    modifier onlySupportedERC20Token(address asset) {
        if (!lrtConfig.isSupportedAsset(asset)) {
            revert ILRTConfig.AssetNotSupported();
        }
        if (asset == LRTConstants.ETH_TOKEN) {
            revert ILRTConfig.ETHNotSupported();
        }
        _;
    }
}
