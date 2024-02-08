// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

contract DeployNodeDelegatorProxy is Script {
    ProxyFactory public proxyFactory;
    ProxyAdmin public proxyAdmin;
    NodeDelegator public nodeDelegatorImplementation;

    address lrtConfigAddr;

    function run() external {
        vm.startBroadcast();
        uint256 chainId = block.chainid;
        if (chainId == 1) {
            //mainnet
            proxyFactory = ProxyFactory(0x673a669425457bCabeb247f56552A0Fd8141cee2);
            proxyAdmin = ProxyAdmin(0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78);
            nodeDelegatorImplementation = NodeDelegator(payable(0xeD510dea149D14c1EB5f973004E0111afdb3B179));
            lrtConfigAddr = 0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7;
        } else if (chainId == 5) {
            // goerli
            proxyFactory = ProxyFactory(0x4ae77FdfB3BBBe99598CAfaE4c369b604b6d9e02);
            proxyAdmin = ProxyAdmin(0xa6A6b35d84B20077c6f3d30b86547fF837260407);
            nodeDelegatorImplementation = NodeDelegator(payable(0xD73Cd1aaE045653474B873f3275BA2BE2744c8B4));
            lrtConfigAddr = 0x6d7888Bc794C1104C64c28F4e849B7AE68231b6d;
        } else {
            revert("Not Applicable");
        }

        bytes32 saltOne = keccak256(abi.encodePacked("NodeDelegatorProxy index 5"));
        address nodeDelegatorProxyIndexFive =
            proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltOne);

        console.log("NodeDelegator deployed at: %s", address(nodeDelegatorProxyIndexFive));

        bytes32 saltTwo = keccak256(abi.encodePacked("NodeDelegatorProxy index 6"));
        address nodeDelegatorProxyIndexSix =
            proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), saltTwo);
        console.log("NodeDelegator deployed at: %s", address(nodeDelegatorProxyIndexSix));

        // initialize the proxies
        NodeDelegator(payable(nodeDelegatorProxyIndexFive)).initialize(lrtConfigAddr);
        NodeDelegator(payable(nodeDelegatorProxyIndexSix)).initialize(lrtConfigAddr);

        vm.stopBroadcast();
    }
}
