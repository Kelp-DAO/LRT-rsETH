// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";
import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// import contract to be upgraded
// e.g. import "contracts/LRTConfig.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";

contract UpgradeLRT is Script {
    ProxyAdmin public proxyAdmin;

    address public proxyAddress;
    address public newImplementation;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey); // must be the ProxyAdmin owner

        uint256 chainId = block.chainid;
        if (chainId == 1) {
            // mainnet
            proxyAdmin = ProxyAdmin(address(0));
            proxyAddress = address(0);
            newImplementation = address(0);
        } else if (chainId == 5) {
            // goerli
            proxyAdmin = ProxyAdmin(0x19b912EdE7056943B23d237752814438338A9666);
            proxyAddress = 0x991837c651902661fa88B80791d58dF56FD0Dd92; // example NodeDelegatorProxy1
            newImplementation = address(new NodeDelegator());
        } else {
            revert("Unsupported network");
        }

        // upgrade contract
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);

        vm.stopBroadcast();
    }
}
