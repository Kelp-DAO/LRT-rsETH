// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { LRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { RSETH } from "contracts/RSETH.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract DeployLRTDepositPool is Script {
    address public proxyAdminOwner;
    ProxyAdmin public proxyAdmin;

    ProxyFactory public proxyFactory;

    LRTConfig public lrtConfigProxy;
    LRTDepositPool public lrtDepositPoolProxy;
    RSETH public RSETHProxy;

    NodeDelegator public nodeDelegatorProxy1;
    NodeDelegator public nodeDelegatorProxy2;
    NodeDelegator public nodeDelegatorProxy3;
    NodeDelegator public nodeDelegatorProxy4;
    NodeDelegator public nodeDelegatorProxy5;
    address[] public nodeDelegatorContracts;

    function setUpByAdmin() private {
        // add deposit pool to LRT config
        lrtConfigProxy.setContract(LRTConstants.LRT_DEPOSIT_POOL, address(lrtDepositPoolProxy));

        // add minter role to lrtDepositPool so it mint rsETH
        lrtConfigProxy.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPoolProxy));
        address oldDepositPoolProxy = 0x55052ba1a135c43a17cf6CeE58a59c782CeF1Bcf;
        lrtConfigProxy.revokeRole(LRTConstants.MINTER_ROLE, oldDepositPoolProxy);

        // add nodeDelegators to LRTDepositPool queue
        nodeDelegatorContracts.push(address(nodeDelegatorProxy1));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy2));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy3));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy4));
        nodeDelegatorContracts.push(address(nodeDelegatorProxy5));
        lrtDepositPoolProxy.addNodeDelegatorContractToQueue(nodeDelegatorContracts);
    }

    function run() external {
        vm.startBroadcast();
        console.log("Deployment started...");

        proxyFactory = ProxyFactory(0x4ae77FdfB3BBBe99598CAfaE4c369b604b6d9e02);
        proxyAdmin = ProxyAdmin(0x503DCfd945dC6612FAa18823501C05410D7eB646);
        proxyAdminOwner = proxyAdmin.owner();
        lrtConfigProxy = LRTConfig(0x99Abf439a4e9910934Dea47082286a04986820b5);
        RSETHProxy = RSETH(0xDa3FF613C5A44F743E5F46c43D1f6F897F425205);
        nodeDelegatorProxy1 = NodeDelegator(payable(0x89cD79e873DEA08D1AfA173B9160c8D31e4Bc9f0));
        nodeDelegatorProxy2 = NodeDelegator(payable(0x5c5720246d3210E90875015c8439230c027a104b));
        nodeDelegatorProxy3 = NodeDelegator(payable(0x68FBD2a42e5d598dA91161f69a8346aFc9Ad9BA8));
        nodeDelegatorProxy4 = NodeDelegator(payable(0x6E6a5770A3A9A8b8614600d5F0A9d6bDc695CF68));
        nodeDelegatorProxy5 = NodeDelegator(payable(0x51975b2e6E29738B8aaaC8479f929a04c5E1D54c));

        console.log("ProxyAdmin deployed at: ", address(proxyAdmin));
        console.log("Owner of ProxyAdmin: ", proxyAdminOwner);
        console.log("LRTConfig proxy present at: ", address(lrtConfigProxy));

        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
        address lrtDepositPoolImplementation = address(new LRTDepositPool());
        console.log("LRTDepositPool implementation deployed at: ", lrtDepositPoolImplementation);
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");

        bytes32 salt = keccak256(abi.encodePacked("LRT-Stader-Labs"));
        lrtDepositPoolProxy = LRTDepositPool(
            payable(proxyFactory.create(address(lrtDepositPoolImplementation), address(proxyAdmin), salt))
        );
        // init LRTDepositPool
        lrtDepositPoolProxy.initialize(address(lrtConfigProxy));
        console.log("LRTDepositPool proxy deployed at: ", address(lrtDepositPoolProxy));

        setUpByAdmin();

        console.log("Deployment Done.");
        console.log("-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=");
    }
}
