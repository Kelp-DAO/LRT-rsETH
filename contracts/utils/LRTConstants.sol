// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { ILRTConfig } from "../interfaces/ILRTConfig.sol";

library LRTConstants {
    //tokens
    bytes32 public constant ST_ETH_TOKEN = keccak256("ST_ETH_TOKEN");
    bytes32 public constant ETHX_TOKEN = keccak256("ETHX_TOKEN");
    bytes32 public constant SFRX_ETH_TOKEN = keccak256("SFRX_ETH_TOKEN");
    // native ETH as ERC20 for ease of implementation
    address public constant ETH_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    //contracts
    bytes32 public constant LRT_ORACLE = keccak256("LRT_ORACLE");
    bytes32 public constant LRT_DEPOSIT_POOL = keccak256("LRT_DEPOSIT_POOL");
    bytes32 public constant LRT_WITHDRAW_MANAGER = keccak256("LRT_WITHDRAW_MANAGER");
    bytes32 public constant LRT_UNSTAKING_VAULT = keccak256("LRT_UNSTAKING_VAULT");
    bytes32 public constant LRT_CONVERTER = keccak256("LRT_CONVERTER");
    bytes32 public constant REWARD_RECEIVER = keccak256("REWARD_RECEIVER");
    bytes32 public constant PROTOCOL_TREASURY = keccak256("PROTOCOL_TREASURY");
    bytes32 public constant PUBKEY_REGISTRY = keccak256("PUBKEY_REGISTRY");

    bytes32 public constant BEACON_CHAIN_ETH_STRATEGY = keccak256("BEACON_CHAIN_ETH_STRATEGY");
    bytes32 public constant EIGEN_STRATEGY_MANAGER = keccak256("EIGEN_STRATEGY_MANAGER");
    bytes32 public constant EIGEN_POD_MANAGER = keccak256("EIGEN_POD_MANAGER");
    bytes32 public constant EIGEN_DELEGATION_MANAGER = keccak256("EIGEN_DELEGATION_MANAGER");
    bytes32 public constant EIGEN_REWARDS_COORDINATOR = keccak256("EIGEN_REWARDS_COORDINATOR");

    //Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TIME_LOCK_ROLE = keccak256("TIME_LOCK_ROLE");

    // constants
    uint256 public constant ONE_E_9 = 1e9;

    // Contract getters
    function unstakingVault(ILRTConfig config) internal view returns (address) {
        return config.getContract(LRT_UNSTAKING_VAULT);
    }

    function delegationManager(ILRTConfig config) internal view returns (address) {
        return config.getContract(EIGEN_DELEGATION_MANAGER);
    }

    function rewardsCoordinator(ILRTConfig config) internal view returns (address) {
        return config.getContract(EIGEN_REWARDS_COORDINATOR);
    }

    function strategyManager(ILRTConfig config) internal view returns (address) {
        return config.getContract(EIGEN_STRATEGY_MANAGER);
    }

    function lrtConverter(ILRTConfig config) internal view returns (address) {
        return config.getContract(LRT_CONVERTER);
    }

    function depositPool(ILRTConfig config) internal view returns (address) {
        return config.getContract(LRT_DEPOSIT_POOL);
    }

    function lrtOracle(ILRTConfig config) internal view returns (address) {
        return config.getContract(LRT_ORACLE);
    }

    function rewardReceiver(ILRTConfig config) internal view returns (address) {
        return config.getContract(REWARD_RECEIVER);
    }

    function protocolTreasury(ILRTConfig config) internal view returns (address) {
        return config.getContract(PROTOCOL_TREASURY);
    }

    function pubkeyRegistry(ILRTConfig config) internal view returns (address) {
        return config.getContract(PUBKEY_REGISTRY);
    }

    function beaconChainETHStrategy(ILRTConfig config) internal view returns (address) {
        return config.getContract(BEACON_CHAIN_ETH_STRATEGY);
    }

    function eigenPodManager(ILRTConfig config) internal view returns (address) {
        return config.getContract(EIGEN_POD_MANAGER);
    }

    function withdrawManager(ILRTConfig config) internal view returns (address) {
        return config.getContract(LRT_WITHDRAW_MANAGER);
    }
}
