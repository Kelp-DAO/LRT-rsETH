// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";

/// @dev script to update asset strategy
contract UpdateAssetStrategy is Script {
    LRTConfig public lrtConfigProxy;

    function setUp() public {
        address lrtConfigProxyAddress = 0x0000000000000000000000000000000000000000;
        lrtConfigProxy = LRTConfig(lrtConfigProxyAddress);
    }

    function run() external {
        vm.startBroadcast();
        console.log("UpdateAssetStrategy started...");

        address asset = 0x0000000000000000000000000000000000000000;
        address assetStrategy = 0x0000000000000000000000000000000000000000;
        // update asset strategy
        lrtConfigProxy.updateAssetStrategy(asset, assetStrategy);

        vm.stopBroadcast();
        console.log("UpdateAssetStrategy finished.");
    }
}
