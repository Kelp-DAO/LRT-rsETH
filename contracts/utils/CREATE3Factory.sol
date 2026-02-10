// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { CREATE3 } from "./CREATE3.sol";

/// @title CREATE3Factory
/// @notice Factory contract for deploying contracts using CREATE3
/// @dev This factory can be deployed at the same address on multiple chains
contract CREATE3Factory {
    /// @notice Emitted when a contract is deployed
    event ContractDeployed(bytes32 indexed salt, address indexed deployedAddress);

    /// @notice Deploy a contract using CREATE3
    /// @param salt The salt for deterministic address generation
    /// @param creationCode The contract creation code with constructor parameters
    /// @return deployed The address of the deployed contract
    function deploy(bytes32 salt, bytes memory creationCode) external payable returns (address deployed) {
        deployed = CREATE3.deploy(salt, creationCode, msg.value);
        emit ContractDeployed(salt, deployed);
    }

    /// @notice Get the deployed address for a given salt
    /// @param salt The salt used for deployment
    /// @return The deterministic address
    function getDeployed(bytes32 salt) external view returns (address) {
        return CREATE3.getDeployed(salt);
    }
}
