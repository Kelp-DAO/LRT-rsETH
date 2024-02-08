// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { NodeDelegator } from "contracts/NodeDelegator.sol";

contract DeployNodeDelegatorImplementation is Script {
    NodeDelegator public nodeDelegatorImplementation;

    function run() external {
        vm.startBroadcast();
        nodeDelegatorImplementation = new NodeDelegator();

        console.log("New NodeDelegator implementation deployed at: %s", address(nodeDelegatorImplementation));

        vm.stopBroadcast();
    }
}
