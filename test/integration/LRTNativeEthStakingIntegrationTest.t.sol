// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";

import { ProxyFactory } from "script/foundry-scripts/utils/ProxyFactory.sol";
import { LRTConfig, ILRTConfig, LRTConstants } from "contracts/LRTConfig.sol";
import { RSETH } from "contracts/RSETH.sol";
import { LRTOracle } from "contracts/LRTOracle.sol";
import { OneETHPriceOracle } from "contracts/oracles/OneETHPriceOracle.sol";
import { NodeDelegator } from "contracts/NodeDelegator.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
import { getLSTs } from "script/foundry-scripts/DeployLRT.s.sol";
import { IEigenPod, IBeaconDeposit } from "contracts/interfaces/IEigenPod.sol";

import { ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract LRTNativeEthStakingIntegrationTest is Test {
    uint256 public fork;
    address public admin;
    address public manager;
    address public operator;

    ProxyFactory proxyFactory;
    ProxyAdmin proxyAdmin;
    LRTDepositPool public lrtDepositPool;
    LRTConfig public lrtConfig;
    RSETH public rseth;
    LRTOracle public lrtOracle;
    NodeDelegator public nodeDelegator1;

    function _upgradeAllContracts() internal {
        vm.startPrank(admin);

        // upgrade lrtConfig
        address proxyAddress = address(lrtConfig);
        address newImplementation = address(new LRTConfig());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);

        // upgrade lrtDepositPool
        proxyAddress = address(lrtDepositPool);
        newImplementation = address(new LRTDepositPool());
        proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);

        // upgrade all ndcs
        address[] memory ndcs = lrtDepositPool.getNodeDelegatorQueue();
        newImplementation = address(new NodeDelegator());
        for (uint256 i = 0; i < ndcs.length; i++) {
            proxyAddress = address(ndcs[i]);
            proxyAdmin.upgrade(ITransparentUpgradeableProxy(proxyAddress), newImplementation);
        }

        vm.stopPrank();

        // Add eth as supported asset
        vm.prank(admin);
        lrtConfig.addNewSupportedAsset(LRTConstants.ETH_TOKEN, 100_000 ether);

        // add oracle for ETH
        address oneETHOracle = address(new OneETHPriceOracle());
        vm.startPrank(manager);
        lrtOracle.updatePriceOracleFor(LRTConstants.ETH_TOKEN, oneETHOracle);
        vm.stopPrank();
    }

    function setUp() public {
        string memory ethMainnetRPC = vm.envString("MAINNET_RPC_URL");
        fork = vm.createSelectFork(ethMainnetRPC);

        admin = 0xb9577E83a6d9A6DE35047aa066E3758221FE0DA2;
        manager = 0xCbcdd778AA25476F203814214dD3E9b9c46829A1;
        operator = makeAddr("operator");

        proxyFactory = ProxyFactory(0x673a669425457bCabeb247f56552A0Fd8141cee2);
        proxyAdmin = ProxyAdmin(0xb61e0E39b6d4030C36A176f576aaBE44BF59Dc78);
        lrtDepositPool = LRTDepositPool(payable(0x036676389e48133B63a802f8635AD39E752D375D));
        lrtConfig = LRTConfig(0x947Cb49334e6571ccBFEF1f1f1178d8469D65ec7);
        rseth = RSETH(0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7);
        lrtOracle = LRTOracle(0x349A73444b1a310BAe67ef67973022020d70020d);
        nodeDelegator1 = NodeDelegator(payable(0x07b96Cf1183C9BFf2E43Acf0E547a8c4E4429473));

        // set eigen pod manager in lrt config
        address eigenPodManager = 0x91E677b07F7AF907ec9a428aafA9fc14a0d3A338;
        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, eigenPodManager);
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operator);
        vm.stopPrank();

        _upgradeAllContracts();
    }

    function test_completeNativeEthFlow() external {
        address alice = makeAddr("alice");
        vm.deal(alice, 100 ether);

        // deposit by user alice
        uint256 aliceBalanceBefore = alice.balance;
        uint256 depositPoolBalanceBefore = address(lrtDepositPool).balance;
        (
            uint256 assetLyingInDepositPoolInitially,
            uint256 assetLyingInNDCsInitially,
            uint256 assetStakedInEigenLayerInitially
        ) = lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);

        uint256 depositAmount = 66 ether;
        vm.prank(alice);
        lrtDepositPool.depositETH{ value: depositAmount }(0, "");

        uint256 aliceBalanceAfter = alice.balance;
        uint256 depositPoolBalanceAfter = address(lrtDepositPool).balance;
        (uint256 assetLyingInDepositPoolNow, uint256 assetLyingInNDCsNow, uint256 assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);

        assertEq(aliceBalanceAfter, aliceBalanceBefore - depositAmount);
        assertEq(depositPoolBalanceAfter, depositPoolBalanceBefore + depositAmount);
        assertEq(
            assetLyingInDepositPoolNow,
            assetLyingInDepositPoolInitially + depositAmount,
            "eth not transferred to deposit pool"
        );
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially);
        assertEq(assetStakedInEigenLayerNow, assetStakedInEigenLayerInitially);

        // move eth from deposit pool to ndc
        vm.prank(manager);
        lrtDepositPool.transferETHToNodeDelegator(0, depositAmount);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount, "eth not transferred to ndc 0");
        assertEq(assetStakedInEigenLayerNow, assetStakedInEigenLayerInitially);

        // create eigen pod
        vm.prank(manager);
        nodeDelegator1.createEigenPod();

        address eigenPod = address(nodeDelegator1.eigenPod());
        // same eigenPod address should be created
        assertEq(eigenPod, 0xf7483e448c1B94Ea557A53d99ebe7b4feE0c91df, "Wrong eigenPod address");

        // stake 32 eth for validator1
        bytes memory pubkey =
            hex"8ff0088bf2bc73a41c74d1b1c6c997e4963ceffde55a09fef27596016d919b74b45372e8aa69fda5aac38a0c1a38dfd5";
        bytes memory signature = hex"95e07ee28de0316ecdf9b528c222d81242898ee0095e284582bb453d331b7760"
            hex"6d8dca23ab8980459ea8a9b9710e2f740fceb1a1c221a7fd75eb3ef4a6b68809"
            hex"f3e76387f01f5d31718e6306375b20b29cb08d1374c7fb125d50c1b2f5a5cc0b";

        bytes32 depositDataRoot = hex"6f30f44f0d8dada6ba5d8fd617c727020c01c697587d1a04ff6661be656198bc";

        vm.prank(operator);
        nodeDelegator1.stake32Eth(pubkey, signature, depositDataRoot);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount - 32 ether);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 32 ether,
            "eth not staked at eigen layer for val1"
        );

        // stake 32 eth for validator2
        pubkey = hex"8f943ad38a85397243a5b2805cad3956f6bc46bcf001f58415ec9a14260fa449b1597a917393560f4a21d59852df30cc";
        signature = hex"88fda50f5197b4d3fc497bcabcd86f5d3c76ad67ff8e752bec96b74fc589ad27"
            hex"3eee3aa72e836a26447680966f5d70900eff7eaaa4d047fe6da5c3d6093aa63c"
            hex"614b443a82c74c9ebc1837efe2bef59e600e3f8008c7aac6bd2eacbffdbae6c4";

        depositDataRoot = hex"fb0f1cf653ff793cd5973b3847e2f91c8cbab3dd22d1c59a8cf86fc5879dc592";

        vm.prank(operator);
        nodeDelegator1.stake32Eth(pubkey, signature, depositDataRoot);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially + depositAmount - 64 ether);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 64 ether,
            "eth not staked at eigen layer for val2"
        );

        // transfer 2 ether back to deposit pool
        vm.prank(manager);
        nodeDelegator1.transferBackToLRTDepositPool(LRTConstants.ETH_TOKEN, 2 ether);

        (assetLyingInDepositPoolNow, assetLyingInNDCsNow, assetStakedInEigenLayerNow) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);
        assertEq(assetLyingInDepositPoolNow, assetLyingInDepositPoolInitially + 2 ether);
        assertEq(assetLyingInNDCsNow, assetLyingInNDCsInitially);
        assertEq(
            assetStakedInEigenLayerNow,
            assetStakedInEigenLayerInitially + 64 ether,
            "eth not transferred back to deposit pool"
        );
    }

    function test_stake32EthValidated() external returns (bytes32) {
        // create eigen pod
        vm.prank(manager);
        nodeDelegator1.createEigenPod();

        address eigenPod = address(nodeDelegator1.eigenPod());
        // same eigenPod address should be created
        assertEq(eigenPod, 0xf7483e448c1B94Ea557A53d99ebe7b4feE0c91df, "Wrong eigenPod address");

        // stake 32 eth for validator1
        bytes memory pubkey =
            hex"8ff0088bf2bc73a41c74d1b1c6c997e4963ceffde55a09fef27596016d919b74b45372e8aa69fda5aac38a0c1a38dfd5";
        bytes memory signature = hex"95e07ee28de0316ecdf9b528c222d81242898ee0095e284582bb453d331b7760"
            hex"6d8dca23ab8980459ea8a9b9710e2f740fceb1a1c221a7fd75eb3ef4a6b68809"
            hex"f3e76387f01f5d31718e6306375b20b29cb08d1374c7fb125d50c1b2f5a5cc0b";

        bytes32 depositDataRoot = hex"6f30f44f0d8dada6ba5d8fd617c727020c01c697587d1a04ff6661be656198bc";

        IBeaconDeposit depositContract = IEigenPod(eigenPod).ethPOS();
        bytes32 expectedDepositRoot = depositContract.get_deposit_root();

        vm.deal(address(nodeDelegator1), 32 ether);
        uint256 balanceBefore = address(nodeDelegator1).balance;

        vm.startPrank(operator);
        nodeDelegator1.stake32EthValidated(pubkey, signature, depositDataRoot, expectedDepositRoot);

        uint256 balanceAfter = address(nodeDelegator1).balance;
        assertEq(balanceAfter, balanceBefore - 32 ether, "stake32eth unsuccesful");

        return expectedDepositRoot;
    }

    function test_withdrawRewards() external {
        // create eigen pod
        vm.prank(manager);
        nodeDelegator1.createEigenPod();

        address eigenPod = address(nodeDelegator1.eigenPod());
        // same eigenPod address should be created
        assertEq(eigenPod, 0xf7483e448c1B94Ea557A53d99ebe7b4feE0c91df, "Wrong eigenPod address");

        // stake 32 eth for validator1
        bytes memory pubkey =
            hex"8ff0088bf2bc73a41c74d1b1c6c997e4963ceffde55a09fef27596016d919b74b45372e8aa69fda5aac38a0c1a38dfd5";
        bytes memory signature = hex"95e07ee28de0316ecdf9b528c222d81242898ee0095e284582bb453d331b7760"
            hex"6d8dca23ab8980459ea8a9b9710e2f740fceb1a1c221a7fd75eb3ef4a6b68809"
            hex"f3e76387f01f5d31718e6306375b20b29cb08d1374c7fb125d50c1b2f5a5cc0b";

        bytes32 depositDataRoot = hex"6f30f44f0d8dada6ba5d8fd617c727020c01c697587d1a04ff6661be656198bc";

        vm.deal(address(nodeDelegator1), 32 ether);
        vm.startPrank(operator);
        nodeDelegator1.stake32Eth(pubkey, signature, depositDataRoot);

        // eigenPod receives some rewards
        uint256 rewardsAmount = 2.5 ether;
        vm.deal(address(eigenPod), rewardsAmount);

        assertEq(address(eigenPod).balance, rewardsAmount);

        nodeDelegator1.initiateWithdrawRewards();

        // rewards moves to delayedWithdrawalRouter
        assertEq(address(eigenPod).balance, 0);

        console.log("block number before vm.roll: ", block.number);
        // set block to  7 days after so that rewards can be claimed
        vm.roll(block.number + 50_400);
        console.log("block number after vm.roll: ", block.number);

        uint256 ndcBalanceBefore = address(nodeDelegator1).balance;

        nodeDelegator1.claimRewards(1);

        assertEq(address(nodeDelegator1).balance, ndcBalanceBefore + rewardsAmount);

        vm.stopPrank();
    }

    function test_removeNDCs() external {
        // ------ STEP1: add NDCs ---------

        NodeDelegator nodeDelegatorImplementation = new NodeDelegator();
        bytes32 salt1 = keccak256(abi.encodePacked("test-ndc1"));
        NodeDelegator testNodeDelegatorProxy1 = NodeDelegator(
            payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt1))
        );

        bytes32 salt2 = keccak256(abi.encodePacked("test-ndc2"));
        NodeDelegator testNodeDelegatorProxy2 = NodeDelegator(
            payable(proxyFactory.create(address(nodeDelegatorImplementation), address(proxyAdmin), salt2))
        );

        testNodeDelegatorProxy1.initialize(address(lrtConfig));
        testNodeDelegatorProxy2.initialize(address(lrtConfig));

        address[] memory testNDCArray = new address[](2);
        testNDCArray[0] = address(testNodeDelegatorProxy1);
        testNDCArray[1] = address(testNodeDelegatorProxy2);

        // add ndcs to queue
        vm.prank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(testNDCArray);

        assertTrue(lrtDepositPool.isNodeDelegator(address(testNodeDelegatorProxy1)) != 0);
        assertTrue(lrtDepositPool.isNodeDelegator(address(testNodeDelegatorProxy2)) != 0);

        // ------ STEP2: remove NDCs ---------

        vm.prank(admin);
        lrtDepositPool.removeManyNodeDelegatorContractsFromQueue(testNDCArray);

        assertTrue(lrtDepositPool.isNodeDelegator(address(testNodeDelegatorProxy1)) == 0);
        assertTrue(lrtDepositPool.isNodeDelegator(address(testNodeDelegatorProxy2)) == 0);
    }
}
