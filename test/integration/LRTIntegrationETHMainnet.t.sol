// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import {
    LRTIntegrationTest,
    ERC20,
    NodeDelegator,
    LRTOracle,
    RSETH,
    LRTConfig,
    LRTDepositPool
} from "./LRTIntegrationTest.t.sol";

import { RSETHPriceFeed } from "../../contracts/oracles/RSETHPriceFeed.sol";

contract LRTIntegrationTestETHMainnet is LRTIntegrationTest {
    function setUp() public override {
        string memory ethMainnetRPC = vm.envString("MAINNET_RPC_URL");
        fork = vm.createSelectFork(ethMainnetRPC);

        admin = 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2;
        manager = 0xCbcdd778AA25476F203814214dD3E9b9c46829A1;

        stWhale = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        ethXWhale = 0x1a0EBB8B15c61879a8e8DA7817Bb94374A7c4007;

        stEthOracle = 0x4cB8d6DCd56d6b371210E70837753F2a835160c4;
        ethxPriceOracle = 0x3D08ccb47ccCde84755924ED6B0642F9aB30dFd2;

        EIGEN_STRATEGY_MANAGER = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A;
        EIGEN_STETH_STRATEGY = 0x93c4b944D05dfe6df7645A86cd2206016c51564D;
        EIGEN_ETHX_STRATEGY = 0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d;

        lrtDepositPool = LRTDepositPool(payable(0x036676389e48133B63a802f8635AD39E752D375D));
        lrtConfig = LRTConfig(0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7);
        rseth = RSETH(0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7);
        lrtOracle = LRTOracle(0x349A73444b1a310BAe67ef67973022020d70020d);
        nodeDelegator1 = NodeDelegator(payable(0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473));

        stETHAddress = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
        ethXAddress = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;

        amountToTransfer = 0.11 ether;

        vm.startPrank(ethXWhale);
        ERC20(ethXAddress).approve(address(lrtDepositPool), amountToTransfer);
        lrtDepositPool.depositAsset(ethXAddress, amountToTransfer, minAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegator = 0;

        vm.prank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegator, ethXAddress, amountToTransfer);
    }

    function test_morphoPriceFeed() public {
        address ethToUSDAggregatorAddress = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        address rsETHOracle = 0x349A73444b1a310BAe67ef67973022020d70020d;
        RSETHPriceFeed priceFeed = new RSETHPriceFeed(ethToUSDAggregatorAddress, rsETHOracle, "RSETH / USD");

        console.log("desc", priceFeed.description());
        console.log("decimals", priceFeed.decimals());
        console.log("version", priceFeed.version());
        // fetch answer from latestRound
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        console.log("roundId", roundId);
        console.log("answer", uint256(answer));
        console.log("startedAt", startedAt);
        console.log("updatedAt", updatedAt);
        console.log("answeredInRound", answeredInRound);
    }
}
