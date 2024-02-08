// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import { BaseTest } from "./BaseTest.t.sol";
import { LRTDepositPool } from "contracts/LRTDepositPool.sol";
import { RSETHTest, ILRTConfig, UtilLib, LRTConstants } from "./RSETHTest.t.sol";
import { ILRTDepositPool } from "contracts/interfaces/ILRTDepositPool.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract LRTOracleMock {
    function getAssetPrice(address) external pure returns (uint256) {
        return 1e18;
    }

    function rsETHPrice() external pure returns (uint256) {
        return 1e18;
    }
}

contract MockNodeDelegator {
    address[] public assets;
    uint256[] public assetBalances;

    constructor(address[] memory _assets, uint256[] memory _assetBalances) {
        assets = _assets;
        assetBalances = _assetBalances;
    }

    function getAssetBalance(address) external pure returns (uint256) {
        return 1e18;
    }

    function getAssetBalances() external view returns (address[] memory, uint256[] memory) {
        return (assets, assetBalances);
    }

    function getETHEigenPodBalance() external pure returns (uint256) {
        return 1e18;
    }

    function removeAssetBalance() external {
        assetBalances[0] = 0;
        assetBalances[1] = 0;
    }

    function sendETHFromDepositPoolToNDC() external payable {
        // do nothing
    }
}

contract LRTDepositPoolTest is BaseTest, RSETHTest {
    LRTDepositPool public lrtDepositPool;

    uint256 public minimunAmountOfRSETHToReceive;
    string public referralId;

    event ETHDeposit(address indexed depositor, uint256 depositAmount, uint256 rsethMintAmount, string referralId);

    function setUp() public virtual override(RSETHTest, BaseTest) {
        super.setUp();

        // deploy LRTDepositPool
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        LRTDepositPool contractImpl = new LRTDepositPool();
        TransparentUpgradeableProxy contractProxy =
            new TransparentUpgradeableProxy(address(contractImpl), address(proxyAdmin), "");

        lrtDepositPool = LRTDepositPool(payable(contractProxy));

        // initialize RSETH. LRTCOnfig is already initialized in RSETHTest
        rseth.initialize(address(admin), address(lrtConfig));
        vm.startPrank(admin);
        // add rsETH to LRT config
        lrtConfig.setRSETH(address(rseth));
        // add oracle to LRT config
        lrtConfig.setContract(LRTConstants.LRT_ORACLE, address(new LRTOracleMock()));

        // add minter role for rseth to lrtDepositPool
        lrtConfig.grantRole(LRTConstants.MINTER_ROLE, address(lrtDepositPool));

        vm.stopPrank();

        minimunAmountOfRSETHToReceive = 0;
        referralId = "42";

        // add manager role within LRTConfig
        vm.startPrank(admin);
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);
        vm.stopPrank();

        vm.startPrank(manager);
        // set ETH as supported token
        lrtConfig.addNewSupportedAsset(LRTConstants.ETH_TOKEN, 100_000 ether);
        vm.stopPrank();
    }
}

contract LRTDepositPoolInitialize is LRTDepositPoolTest {
    function test_RevertWhenLRTConfigIsZeroAddress() external {
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        lrtDepositPool.initialize(address(0));
    }

    function test_InitializeContractsVariables() external {
        lrtDepositPool.initialize(address(lrtConfig));

        assertEq(lrtDepositPool.maxNodeDelegatorLimit(), 10, "Max node delegator count is not set");
        assertEq(address(lrtConfig), address(lrtDepositPool.lrtConfig()), "LRT config address is not set");
    }
}

contract LRTDepositPoolDepositETH is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenDepositAmountIsZero() external {
        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositETH{ value: 0 }(minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenDepositAmountIsLessThanMinAmountToDeposit() external {
        uint256 minAmountToDeposit = lrtDepositPool.minAmountToDeposit();
        uint256 amountToDeposit = minAmountToDeposit / 2;

        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositETH{ value: amountToDeposit }(minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenMinAmountToReceiveIsNotMetWhenCallingDepositETH() external {
        vm.startPrank(alice);

        // increase the minimum amount of rsETH to receive to an amount that is not met
        minimunAmountOfRSETHToReceive = 100 ether;

        vm.expectRevert(ILRTDepositPool.MinimumAmountToReceiveNotMet.selector);
        lrtDepositPool.depositETH{ value: 1 ether }(minimunAmountOfRSETHToReceive, referralId);

        vm.stopPrank();
    }

    function test_DepositETH() external {
        vm.startPrank(alice);

        // alice balance of rsETH before deposit
        uint256 aliceBalanceBefore = rseth.balanceOf(address(alice));

        minimunAmountOfRSETHToReceive = lrtDepositPool.getRsETHAmountToMint(LRTConstants.ETH_TOKEN, 1 ether);

        expectEmit();
        emit ETHDeposit(alice, 1 ether, minimunAmountOfRSETHToReceive, referralId);
        lrtDepositPool.depositETH{ value: 1 ether }(minimunAmountOfRSETHToReceive, referralId);

        // alice balance of rsETH after deposit
        uint256 aliceBalanceAfter = rseth.balanceOf(address(alice));
        vm.stopPrank();

        assertEq(address(lrtDepositPool).balance, 1 ether, "Total ETH deposits is not set");
        assertGt(aliceBalanceAfter + 1, aliceBalanceBefore + minimunAmountOfRSETHToReceive, "Alice balance is not set");
    }
}

contract LRTDepositPoolDepositAsset is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_RevertWhenDepositAmountIsZero() external {
        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0, minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenDepositAmountIsLessThanMinAmountToDeposit() external {
        vm.startPrank(admin);
        lrtDepositPool.setMinAmountToDeposit(1 ether);
        vm.stopPrank();

        vm.expectRevert(ILRTDepositPool.InvalidAmountToDeposit.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0.5 ether, minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAsset = makeAddr("randomAsset");

        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        lrtDepositPool.depositAsset(randomAsset, 1 ether, minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenDepositAmountExceedsLimit() external {
        vm.prank(manager);
        lrtConfig.updateAssetDepositLimit(ethXAddress, 1 ether);

        vm.expectRevert(ILRTDepositPool.MaximumDepositLimitReached.selector);
        lrtDepositPool.depositAsset(ethXAddress, 2 ether, minimunAmountOfRSETHToReceive, referralId);
    }

    function test_RevertWhenMinAmountToReceiveIsNotMet() external {
        vm.startPrank(alice);

        ethX.approve(address(lrtDepositPool), 2 ether);

        // increase the minimum amount of rsETH to receive to an amount that is not met
        minimunAmountOfRSETHToReceive = 100 ether;

        vm.expectRevert(ILRTDepositPool.MinimumAmountToReceiveNotMet.selector);
        lrtDepositPool.depositAsset(ethXAddress, 0.5 ether, minimunAmountOfRSETHToReceive, referralId);

        vm.stopPrank();
    }

    function test_DepositAsset() external {
        vm.startPrank(alice);

        // alice balance of rsETH before deposit
        uint256 aliceBalanceBefore = rseth.balanceOf(address(alice));

        minimunAmountOfRSETHToReceive = lrtDepositPool.getRsETHAmountToMint(ethXAddress, 2 ether);

        ethX.approve(address(lrtDepositPool), 2 ether);
        lrtDepositPool.depositAsset(ethXAddress, 2 ether, minimunAmountOfRSETHToReceive, referralId);

        // alice balance of rsETH after deposit
        uint256 aliceBalanceAfter = rseth.balanceOf(address(alice));
        vm.stopPrank();

        assertEq(lrtDepositPool.getTotalAssetDeposits(ethXAddress), 2 ether, "Total asset deposits is not set");
        assertGt(aliceBalanceAfter, aliceBalanceBefore, "Alice balance is not set");
    }

    function test_FuzzDepositAsset(uint256 amountDeposited) external {
        uint256 stETHDepositLimit = lrtConfig.depositLimitByAsset(address(stETH));
        vm.assume(amountDeposited > 0 && amountDeposited <= stETHDepositLimit);

        uint256 aliceBalanceBefore = rseth.balanceOf(address(alice));

        vm.startPrank(alice);
        stETH.approve(address(lrtDepositPool), amountDeposited);
        lrtDepositPool.depositAsset(address(stETH), amountDeposited, minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        uint256 aliceBalanceAfter = rseth.balanceOf(address(alice));

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(address(stETH)), amountDeposited, "Total asset deposits is not set"
        );
        assertGt(aliceBalanceAfter, aliceBalanceBefore, "Alice balance is not set");
    }
}

contract LRTDepositPoolGetRsETHAmountToMint is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetRsETHAmountToMintWhenAssetIsLST() external {
        uint256 amountToDeposit = 1 ether;
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(ethXAddress, amountToDeposit);
        vm.stopPrank();

        assertEq(
            lrtDepositPool.getRsETHAmountToMint(ethXAddress, amountToDeposit),
            1 ether,
            "RsETH amount to mint is incorrect"
        );
    }

    function test_GetRsETHAmountToMintWhenAssetisNativeETH() external {
        uint256 amountToDeposit = 1 ether;

        assertEq(
            lrtDepositPool.getRsETHAmountToMint(address(0), amountToDeposit),
            1 ether,
            "RsETH amount to mint is incorrect"
        );
    }
}

contract LRTDepositPoolGetAssetCurrentLimit is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetAssetCurrentLimit() external {
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(address(stETH), 1 ether);
        vm.stopPrank();

        assertEq(lrtDepositPool.getAssetCurrentLimit(address(stETH)), 1 ether, "Asset current limit is not set");
    }

    function test_GetAssetCurrentLimitAfterAssetIsDeposited() external {
        vm.startPrank(manager);
        lrtConfig.updateAssetDepositLimit(address(stETH), 10 ether);
        vm.stopPrank();

        // deposit 1 ether stETH
        vm.startPrank(alice);
        stETH.approve(address(lrtDepositPool), 6 ether);
        lrtDepositPool.depositAsset(address(stETH), 6 ether, minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        assertEq(lrtDepositPool.getAssetCurrentLimit(address(stETH)), 4 ether, "Asset current limit is not set");
    }
}

contract LRTDepositPoolGetNodeDelegatorQueue is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetNodeDelegatorQueue() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue(), nodeDelegatorQueue, "Node delegator queue is not set");
    }
}

contract LRTDepositPoolGetTotalAssetDeposits is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetTotalAssetDeposits() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        uint256 amountToDeposit = 1 ether;

        uint256 totalDepositsBefore = lrtDepositPool.getTotalAssetDeposits(address(ethX));

        // deposit ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), amountToDeposit);
        lrtDepositPool.depositAsset(address(ethX), amountToDeposit, minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        assertEq(
            lrtDepositPool.getTotalAssetDeposits(address(ethX)),
            totalDepositsBefore + amountToDeposit,
            "Incorrect total asset deposits amount"
        );
    }
}

contract LRTDepositPoolGetAssetDistributionData is LRTDepositPoolTest {
    address public ethXAddress;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        ethXAddress = address(ethX);
    }

    function test_GetAssetDistributionData() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        // deposit 3 ether ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 3 ether);
        lrtDepositPool.depositAsset(ethXAddress, 3 ether, minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        (uint256 assetLyingInDepositPool, uint256 assetLyingInNDCs, uint256 assetStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(ethXAddress);

        assertEq(assetLyingInDepositPool, 3 ether, "Asset lying in deposit pool is not set");
        assertEq(assetLyingInNDCs, 0, "Asset lying in NDCs is not set");
        assertEq(assetStakedInEigenLayer, 3 ether, "Asset staked in eigen layer is not set");
    }
}

contract LRTDepositPoolGetETHDistributionData is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetETHDistributionData() external {
        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        address nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        address nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        address[] memory nodeDelegatorQueue = new address[](3);
        nodeDelegatorQueue[0] = nodeDelegatorContractOne;
        nodeDelegatorQueue[1] = nodeDelegatorContractTwo;
        nodeDelegatorQueue[2] = nodeDelegatorContractThree;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueue);
        vm.stopPrank();

        // deposit 3 ether
        vm.startPrank(alice);
        lrtDepositPool.depositETH{ value: 5 ether }(minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        (uint256 ethLyingInDepositPool, uint256 ethLyingInNDCs, uint256 ethStakedInEigenLayer) =
            lrtDepositPool.getETHDistributionData();

        assertEq(ethLyingInDepositPool, 5 ether, "ETH lying in deposit pool is not set");
        assertEq(ethLyingInNDCs, 0, "ETH lying in NDCs is not set");
        assertEq(ethStakedInEigenLayer, 3 ether, "ETH staked in eigen layer is not set");

        // check using getAssetDistributionData
        (ethLyingInDepositPool, ethLyingInNDCs, ethStakedInEigenLayer) =
            lrtDepositPool.getAssetDistributionData(LRTConstants.ETH_TOKEN);

        assertEq(ethLyingInDepositPool, 5 ether, "ETH lying in deposit pool is not set");
        assertEq(ethLyingInNDCs, 0, "ETH lying in NDCs is not set");
        assertEq(ethStakedInEigenLayer, 3 ether, "ETH staked in eigen layer is not set");
    }
}

contract LRTDepositPoolAddNodeDelegatorContractToQueue is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorLimitExceedsLimit() external {
        vm.startPrank(admin);

        uint256 maxDelegatorCount = lrtDepositPool.maxNodeDelegatorLimit();

        for (uint256 i = 0; i < maxDelegatorCount; i++) {
            address madeUpNodeDelegatorAddress = makeAddr(string(abi.encodePacked("nodeDelegatorContract", i)));

            address[] memory nodeDelegatorContractArray = new address[](1);
            nodeDelegatorContractArray[0] = madeUpNodeDelegatorAddress;

            lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorContractArray);
        }

        // add one more node delegator contract to go above limit
        vm.expectRevert(ILRTDepositPool.MaximumNodeDelegatorLimitReached.selector);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        vm.stopPrank();
    }

    function test_AddNodeDelegatorContractToQueue() external {
        // get node delegator queue length before adding node delegator contracts
        uint256 nodeDelegatorQueueLengthBefore = lrtDepositPool.getNodeDelegatorQueue().length;

        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        // assert node delegator queue length is the same as nodeDelegatorQueueProspectives length
        assertEq(
            lrtDepositPool.getNodeDelegatorQueue().length,
            nodeDelegatorQueueProspectives.length + nodeDelegatorQueueLengthBefore,
            "Node delegator queue length is not set"
        );

        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0),
            nodeDelegatorQueueProspectives[0],
            "Node delegator index 0 contract is not added"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(1),
            nodeDelegatorQueueProspectives[1],
            "Node delegator index 1 contract is not added"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(2),
            nodeDelegatorQueueProspectives[2],
            "Node delegator index 2 contract is not added"
        );

        // if we add the same node delegator contract again, it should not be added
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);

        assertEq(
            lrtDepositPool.getNodeDelegatorQueue().length,
            nodeDelegatorQueueProspectives.length + nodeDelegatorQueueLengthBefore,
            "Node delegator queue length is not set"
        );
        vm.stopPrank();
    }
}

contract LTRRemoveNodeDelegatorFromQueue is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;

        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(address(nodeDelegatorContractOne));

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorIndexIsNotValid() external {
        address nodeDelegatorContractFour = address(new MockNodeDelegator(new address[](0), new uint256[](0)));

        vm.startPrank(admin);

        vm.expectRevert(ILRTDepositPool.NodeDelegatorNotFound.selector);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractFour);

        vm.stopPrank();
    }

    function test_RevertWhenNodeDelegatorHasAssetBalance() external {
        vm.startPrank(admin);

        uint256 amountToDeposit = 1 ether;
        bytes memory errorData = abi.encodeWithSelector(
            ILRTDepositPool.NodeDelegatorHasAssetBalance.selector,
            address(stETH), // asset
            amountToDeposit // asset balance
        );

        vm.expectRevert(errorData);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractOne);

        vm.stopPrank();
    }

    function test_RemoveNodeDelegatorContractFromQueue() external {
        // mock contract function to remove asset balance from node delegator contract two
        MockNodeDelegator(nodeDelegatorContractTwo).removeAssetBalance();

        // remove node delegator contract one from queue
        vm.startPrank(admin);
        lrtDepositPool.removeNodeDelegatorContractFromQueue(nodeDelegatorContractTwo);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue().length, 2, "Node delegator queue length is not set");
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0), nodeDelegatorContractOne, "Node delegator index 0 contract is not set"
        );
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(1),
            nodeDelegatorContractThree,
            "Node delegator index 1 contract is not set"
        );
    }

    function test_RemoveManyNodeDelegatorContractsFromQueue() external {
        // mock contract function to remove asset balance from node delegator contract one
        MockNodeDelegator(nodeDelegatorContractOne).removeAssetBalance();
        MockNodeDelegator(nodeDelegatorContractTwo).removeAssetBalance();

        // remove node delegator contract one from queue
        address[] memory nodeDelegatorContractsToRemove = new address[](2);
        nodeDelegatorContractsToRemove[0] = nodeDelegatorContractOne;
        nodeDelegatorContractsToRemove[1] = nodeDelegatorContractTwo;

        vm.startPrank(admin);
        lrtDepositPool.removeManyNodeDelegatorContractsFromQueue(nodeDelegatorContractsToRemove);
        vm.stopPrank();

        assertEq(lrtDepositPool.getNodeDelegatorQueue().length, 1, "Node delegator queue length is not set");
        assertEq(
            lrtDepositPool.nodeDelegatorQueue(0),
            nodeDelegatorContractThree,
            "Node delegator index 0 contract is not set"
        );
    }
}

contract LRTDepositPoolTransferAssetToNodeDelegator is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;
        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.transferAssetToNodeDelegator(0, address(ethX), 1 ether);

        vm.stopPrank();
    }

    function test_TransferAssetToNodeDelegator() external {
        // deposit 3 ether ethX
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 3 ether);
        lrtDepositPool.depositAsset(address(ethX), 3 ether, minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegatorContractOneInNDArray;
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (lrtDepositPool.nodeDelegatorQueue(i) == nodeDelegatorContractOne) {
                indexOfNodeDelegatorContractOneInNDArray = i;
                break;
            }
        }

        // transfer 1 ether ethX to node delegator contract one
        vm.startPrank(manager);
        lrtDepositPool.transferAssetToNodeDelegator(indexOfNodeDelegatorContractOneInNDArray, address(ethX), 1 ether);
        vm.stopPrank();

        assertEq(ethX.balanceOf(address(lrtDepositPool)), 2 ether, "Asset amount in lrtDepositPool is incorrect");
        assertEq(ethX.balanceOf(nodeDelegatorContractOne), 1 ether, "Asset is not transferred to node delegator");
    }
}

contract LRTDepositTransferETHToNodeDelegator is LRTDepositPoolTest {
    address public nodeDelegatorContractOne;
    address public nodeDelegatorContractTwo;
    address public nodeDelegatorContractThree;

    address[] public nodeDelegatorQueueProspectives;

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        address[] memory assets = new address[](2);
        assets[0] = address(stETH);
        assets[1] = address(ethX);

        uint256[] memory assetBalances = new uint256[](2);
        assetBalances[0] = 1 ether;
        assetBalances[1] = 1 ether;
        nodeDelegatorContractOne = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractTwo = address(new MockNodeDelegator(assets, assetBalances));
        nodeDelegatorContractThree = address(new MockNodeDelegator(assets, assetBalances));

        nodeDelegatorQueueProspectives.push(nodeDelegatorContractOne);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractTwo);
        nodeDelegatorQueueProspectives.push(nodeDelegatorContractThree);

        // add node delegator contracts to queue
        vm.startPrank(admin);
        lrtDepositPool.addNodeDelegatorContractToQueue(nodeDelegatorQueueProspectives);
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.transferETHToNodeDelegator(0, 1 ether);

        vm.stopPrank();
    }

    function test_TransferETHToNodeDelegator() external {
        // deposit 3 ether
        vm.startPrank(alice);
        lrtDepositPool.depositETH{ value: 3 ether }(minimunAmountOfRSETHToReceive, referralId);
        vm.stopPrank();

        uint256 indexOfNodeDelegatorContractOneInNDArray;
        address[] memory nodeDelegatorArray = lrtDepositPool.getNodeDelegatorQueue();
        for (uint256 i = 0; i < nodeDelegatorArray.length; i++) {
            if (lrtDepositPool.nodeDelegatorQueue(i) == nodeDelegatorContractOne) {
                indexOfNodeDelegatorContractOneInNDArray = i;
                break;
            }
        }

        // transfer 1 ether to node delegator contract one
        vm.startPrank(manager);
        lrtDepositPool.transferETHToNodeDelegator(indexOfNodeDelegatorContractOneInNDArray, 1 ether);
        vm.stopPrank();

        assertEq(address(lrtDepositPool).balance, 2 ether, "ETH amount in lrtDepositPool is incorrect");
        assertEq(address(nodeDelegatorContractOne).balance, 1 ether, "ETH is not transferred to node delegator");
    }
}

contract LRTDepositPoolSwapAssetFromDepositPool is LRTDepositPoolTest {
    event AssetSwapped(
        address indexed fromAsset, address indexed toAsset, uint256 fromAssetAmount, uint256 toAssetAmount
    );

    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));

        // send 5 stETH to manager
        vm.prank(alice);
        stETH.transfer(manager, 5 ether);

        // deposit 5 ethX to lrtDepositPool
        vm.startPrank(alice);
        ethX.approve(address(lrtDepositPool), 5 ether);
        lrtDepositPool.depositAsset(address(ethX), 5 ether, 0, "");
        vm.stopPrank();
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.swapAssetWithinDepositPool(address(stETH), address(ethX), 1 ether, 1 ether);

        vm.stopPrank();
    }

    function test_SwapAssetFromDepositPool() external {
        uint256 amountToSwap = 3 ether;

        uint256 minimumAmountOfEthxToReceive =
            lrtDepositPool.getSwapAssetReturnAmount(address(stETH), address(ethX), amountToSwap);

        uint256 balanceOfEthxBefore = ethX.balanceOf(address(lrtDepositPool));
        uint256 balanceOfStethBefore = stETH.balanceOf(address(lrtDepositPool));

        uint256 managerBalanceOfEthxBefore = ethX.balanceOf(manager);
        uint256 managerBalanceOfStethBefore = stETH.balanceOf(manager);

        vm.startPrank(manager);
        stETH.approve(address(lrtDepositPool), amountToSwap);

        expectEmit();
        emit AssetSwapped(address(stETH), address(ethX), amountToSwap, minimumAmountOfEthxToReceive);
        lrtDepositPool.swapAssetWithinDepositPool(
            address(stETH), address(ethX), amountToSwap, minimumAmountOfEthxToReceive
        );
        vm.stopPrank();

        uint256 balanceOfEthxAfter = ethX.balanceOf(address(lrtDepositPool));
        uint256 balanceOfStethAfter = stETH.balanceOf(address(lrtDepositPool));

        uint256 managerBalanceOfEthxAfter = ethX.balanceOf(manager);
        uint256 managerBalanceOfStethAfter = stETH.balanceOf(manager);

        assertEq(
            balanceOfEthxAfter,
            balanceOfEthxBefore - minimumAmountOfEthxToReceive,
            "Ethx was not removed properly from lrtDepositPool"
        );
        assertEq(
            balanceOfStethAfter, balanceOfStethBefore + amountToSwap, "StETH was not added properly to lrtDepositPool"
        );

        assertEq(
            managerBalanceOfEthxAfter,
            managerBalanceOfEthxBefore + minimumAmountOfEthxToReceive,
            "Ethx was not given properly to manager"
        );
        assertEq(
            managerBalanceOfStethAfter,
            managerBalanceOfStethBefore - amountToSwap,
            "StETH was not removed properly from manager"
        );
    }
}

contract LRTDepositPoolGetSwapAssetReturnAmount is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_GetSwapAssetReturnAmount() external {
        uint256 amountToSwap = 3 ether;

        uint256 minimumAmountOfEthxToReceive =
            lrtDepositPool.getSwapAssetReturnAmount(address(stETH), address(ethX), amountToSwap);

        assertGt(minimumAmountOfEthxToReceive, 1 ether, "Minimum amount of ethx to receive is incorrect");
    }
}

contract LRTDepositPoolUpdateMaxNodeDelegatorLimit is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.updateMaxNodeDelegatorLimit(10);

        vm.stopPrank();
    }

    function test_UpdateMaxNodeDelegatorLimit() external {
        vm.startPrank(admin);
        lrtDepositPool.updateMaxNodeDelegatorLimit(10);
        vm.stopPrank();

        assertEq(lrtDepositPool.maxNodeDelegatorLimit(), 10, "Max node delegator count is not set");
    }
}

contract LRTDepositPoolSetMinAmountToDeposit is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.setMinAmountToDeposit(1 ether);

        vm.stopPrank();
    }

    function test_SetMinAmountToDeposit() external {
        vm.startPrank(admin);
        lrtDepositPool.setMinAmountToDeposit(1 ether);
        vm.stopPrank();

        assertEq(lrtDepositPool.minAmountToDeposit(), 1 ether, "Min amount to deposit is not set");
    }
}

contract LRTDepositPoolPause is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigManager() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        lrtDepositPool.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        lrtDepositPool.pause();
        vm.stopPrank();

        assertTrue(lrtDepositPool.paused(), "LRTDepositPool is not paused");
    }
}

contract LRTDepositPoolUnpause is LRTDepositPoolTest {
    function setUp() public override {
        super.setUp();

        // initialize LRTDepositPool
        lrtDepositPool.initialize(address(lrtConfig));
    }

    function test_RevertWhenNotCalledByLRTConfigAdmin() external {
        vm.startPrank(alice);

        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        lrtDepositPool.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.prank(manager);
        lrtDepositPool.pause();
        vm.prank(admin);
        lrtDepositPool.unpause();

        assertFalse(lrtDepositPool.paused(), "LRTDepositPool is not unpaused");
    }
}
