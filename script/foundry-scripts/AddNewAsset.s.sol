// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/Script.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { SfrxETHPriceOracle } from "contracts/oracles/SfrxETHPriceOracle.sol";

contract AddNewAsset is Script {
    ProxyFactory public proxyFactory;
    ProxyAdmin public proxyAdmin;
    SfrxETHPriceOracle public assetOracle;

    address public asset;

    function run() external {
        vm.startBroadcast();
        uint256 chainId = block.chainid;
        if (chainId == 1) {
            //mainnet
            proxyFactory = ProxyFactory(0x673a669425457bCabeb247f56552A0Fd8141cee2);
            proxyAdmin = ProxyAdmin(0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78);

            asset = 0xac3E018457B222d93114458476f3E3416Abbe38F;
        } else if (chainId == 5) {
            // goerli
            proxyFactory = ProxyFactory(0x4ae77FdfB3BBBe99598CAfaE4c369b604b6d9e02);
            proxyAdmin = ProxyAdmin(0xa6A6b35d84B20077c6f3d30b86547fF837260407);

            asset = 0x5E8422345238F34275888049021821E8E08CAa1f;
        } else {
            revert("Not Applicable");
        }

        address assetOracleImplementation = address(new SfrxETHPriceOracle());
        console.log("SfrxETHPriceOracle Implementation deployed at: %s", address(assetOracleImplementation));

        bytes32 salt = keccak256(abi.encodePacked("SfrxETHPriceOracle"));
        address assetOracleProxy = proxyFactory.create(address(assetOracleImplementation), address(proxyAdmin), salt);
        console.log("SfrxETHPriceOracle Proxy deployed at: %s", address(assetOracleProxy));

        // initialize the proxies
        SfrxETHPriceOracle(address(assetOracleProxy)).initialize(asset);

        // MANUALLY using GNOSIS SAFE

        // ADMIN
        // lrtConfigProxy.setToken(LRTConstants.SFRXETH_TOKEN, sfrxETHAddress);
        // lrtConfigProxy.updateAssetStrategy(sfrxETHAddress, SfrxETHStrategyAddress);

        // Manager
        // lrtConfigProxy.addNewSupportedAsset(sfrxETHAddress, 100_000 ether);
        // lrtOracleProxy.updatePriceOracleFor(sfrxETHAddress, address(assetOracleProxy));

        vm.stopBroadcast();
    }
}
