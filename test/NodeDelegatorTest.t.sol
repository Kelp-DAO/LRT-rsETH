// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

import "forge-std/console.sol";

import { LRTConfigTest, ILRTConfig, LRTConstants, UtilLib, MockStrategy, IERC20 } from "./LRTConfigTest.t.sol";
import { IStrategy } from "contracts/interfaces/IStrategy.sol";
import { NodeDelegator, INodeDelegator } from "contracts/NodeDelegator.sol";
import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import { BeaconChainProofs } from "contracts/interfaces/IEigenPod.sol";

contract MockEigenStrategyManager {
    mapping(address depositor => mapping(address strategy => uint256 shares)) public depositorStrategyShareBalances;

    address[] public strategies;

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares) {
        token.transferFrom(msg.sender, address(strategy), amount);

        shares = amount;

        depositorStrategyShareBalances[msg.sender][address(strategy)] += shares;

        strategies.push(address(strategy));

        return shares;
    }

    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory) {
        uint256[] memory shares = new uint256[](strategies.length);
        IStrategy[] memory strategies_ = new IStrategy[](strategies.length);

        for (uint256 i = 0; i < strategies.length; i++) {
            strategies_[i] = IStrategy(strategies[i]);
            shares[i] = depositorStrategyShareBalances[depositor][strategies[i]];
        }

        return (strategies_, shares);
    }
}

contract MockEigenPodManager {
    mapping(address => address) public ownerToPod;

    function createPod() external {
        if (ownerToPod[msg.sender] != address(0)) {
            return;
        }
        ownerToPod[msg.sender] = address(new MockEigenPod());
    }

    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable {
        // do nothing
    }
}

contract MockEigenPod {
    function verifyWithdrawalCredentialsAndBalance(
        uint64 oracleBlockNumber,
        uint40 validatorIndex,
        BeaconChainProofs.ValidatorFieldsAndBalanceProofs memory proofs,
        bytes32[] calldata validatorFields
    )
        external
        view
        returns (uint256)
    {
        return 32 gwei;
    }

    receive() external payable { }
}

contract NodeDelegatorTest is LRTConfigTest {
    NodeDelegator public nodeDel;
    address public operator;

    MockEigenStrategyManager public mockEigenStrategyManager;

    MockStrategy public stETHMockStrategy;
    MockStrategy public ethXMockStrategy;
    address public mockLRTDepositPool;

    MockEigenPodManager public mockEigenPodManager;

    event UpdatedLRTConfig(address indexed lrtConfig);
    event AssetDepositIntoStrategy(address indexed asset, address indexed strategy, uint256 depositAmount);
    event ETHDepositFromDepositPool(uint256 depositAmount);

    uint256 public mockUserUnderlyingViewBalance;

    function setUp() public virtual override {
        super.setUp();

        operator = makeAddr("operator");

        // initialize LRTConfig
        lrtConfig.initialize(admin, address(stETH), address(ethX), rsethMock);

        // add mockEigenStrategyManager to LRTConfig
        mockEigenStrategyManager = new MockEigenStrategyManager();
        vm.startPrank(admin);
        lrtConfig.setContract(LRTConstants.EIGEN_STRATEGY_MANAGER, address(mockEigenStrategyManager));

        mockEigenPodManager = new MockEigenPodManager();
        lrtConfig.setContract(LRTConstants.EIGEN_POD_MANAGER, address(mockEigenPodManager));

        // add manager role
        lrtConfig.grantRole(LRTConstants.MANAGER, manager);

        // add operator role
        lrtConfig.grantRole(LRTConstants.OPERATOR_ROLE, operator);

        // add mockStrategy to LRTConfig
        mockUserUnderlyingViewBalance = 10 ether;
        ethXMockStrategy = new MockStrategy(address(ethX), mockUserUnderlyingViewBalance);
        stETHMockStrategy = new MockStrategy(address(stETH), mockUserUnderlyingViewBalance);

        lrtConfig.updateAssetStrategy(address(ethX), address(ethXMockStrategy));
        lrtConfig.updateAssetStrategy(address(stETH), address(stETHMockStrategy));

        // add mockLRTDepositPool to LRTConfig
        mockLRTDepositPool = makeAddr("mockLRTDepositPool");
        lrtConfig.setContract(LRTConstants.LRT_DEPOSIT_POOL, mockLRTDepositPool);
        vm.stopPrank();

        // deploy NodeDelegator
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        NodeDelegator nodeDelImpl = new NodeDelegator();
        TransparentUpgradeableProxy nodeDelProxy =
            new TransparentUpgradeableProxy(address(nodeDelImpl), address(proxyAdmin), "");

        nodeDel = NodeDelegator(payable(nodeDelProxy));
    }
}

contract NodeDelegatorInitialize is NodeDelegatorTest {
    function test_RevertInitializeIfAlreadyInitialized() external {
        nodeDel.initialize(address(lrtConfig));

        vm.startPrank(admin);
        // cannot initialize again
        vm.expectRevert("Initializable: contract is already initialized");
        nodeDel.initialize(address(lrtConfig));
        vm.stopPrank();
    }

    function test_RevertInitializeIfLRTConfigIsZero() external {
        vm.startPrank(admin);
        vm.expectRevert(UtilLib.ZeroAddressNotAllowed.selector);
        nodeDel.initialize(address(0));
        vm.stopPrank();
    }

    function test_SetInitializableValues() external {
        expectEmit();
        emit UpdatedLRTConfig(address(lrtConfig));
        nodeDel.initialize(address(lrtConfig));

        assertEq(address(nodeDel.lrtConfig()), address(lrtConfig));
    }
}

contract NodeDelegatorCreateEigenPod is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.createEigenPod();
        vm.stopPrank();
    }

    function test_CreateEigenPod() external {
        assertEq(address(nodeDel.eigenPod()), address(0));

        vm.startPrank(manager);
        nodeDel.createEigenPod();
        vm.stopPrank();

        assertFalse(address(nodeDel.eigenPod()) == address(0));
    }
}

contract NodeDelegatorMaxApproveToEigenStrategyManager is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.maxApproveToEigenStrategyManager(randomAddress);
        vm.stopPrank();
    }

    function test_MaxApproveToEigenStrategyManager() external {
        vm.startPrank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        vm.stopPrank();

        // check that the nodeDelegator has max approved the eigen strategy manager
        assertEq(ethX.allowance(address(nodeDel), address(mockEigenStrategyManager)), type(uint256).max);
    }
}

contract NodeDelegatorDepositAssetIntoStrategy is NodeDelegatorTest {
    uint256 public amountDeposited;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        amountDeposited = 10 ether;
        vm.prank(bob);
        ethX.transfer(address(nodeDel), amountDeposited);

        // max approve nodeDelegator to deposit into strategy
        vm.prank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
    }

    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.depositAssetIntoStrategy(address(ethX));

        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.depositAssetIntoStrategy(randomAddress);
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();
    }

    function test_RevertWhenAnStrategyIsNotSetForAsset() external {
        address randomAddress = address(0x123);
        uint256 depositLimit = 100 ether;
        vm.prank(admin);
        lrtConfig.addNewSupportedAsset(randomAddress, depositLimit);

        vm.startPrank(manager);
        vm.expectRevert(INodeDelegator.StrategyIsNotSetForAsset.selector);
        nodeDel.depositAssetIntoStrategy(randomAddress);
        vm.stopPrank();
    }

    function test_DepositAssetIntoStrategy() external {
        vm.startPrank(manager);
        expectEmit();
        emit AssetDepositIntoStrategy(address(ethX), address(ethXMockStrategy), amountDeposited);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();

        // check that strategy received LST via the eigen strategy manager
        assertEq(ethX.balanceOf(address(ethXMockStrategy)), amountDeposited);
    }
}

contract NodeDelegatorTransferBackToLRTDepositPool is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        vm.prank(admin);
        lrtConfig.addNewSupportedAsset(LRTConstants.ETH_TOKEN, 100_000 ether);
        nodeDel.initialize(address(lrtConfig));

        // transfer ethX to NodeDelegator
        vm.prank(bob);
        ethX.transfer(address(nodeDel), 10 ether);
    }

    function test_RevertWhenContractIsPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.transferBackToLRTDepositPool(address(ethX), 10 ether);

        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.transferBackToLRTDepositPool(address(ethX), 10 ether);
        vm.stopPrank();
    }

    function test_RevertWhenAssetIsNotSupported() external {
        address randomAddress = address(0x123);
        vm.startPrank(manager);
        vm.expectRevert(ILRTConfig.AssetNotSupported.selector);
        nodeDel.transferBackToLRTDepositPool(randomAddress, 10 ether);
        vm.stopPrank();
    }

    function test_TransferBackToLRTDepositPool() external {
        uint256 amountToDeposit = 3 ether;

        uint256 nodeDelBalanceBefore = ethX.balanceOf(address(nodeDel));

        // transfer funds in NodeDelegator to to LRTDepositPool
        vm.startPrank(manager);
        nodeDel.transferBackToLRTDepositPool(address(ethX), amountToDeposit);
        vm.stopPrank();

        uint256 nodeDelBalanceAfter = ethX.balanceOf(address(nodeDel));

        assertLt(nodeDelBalanceAfter, nodeDelBalanceBefore, "NodeDelegator balance did not increase");
        assertEq(nodeDelBalanceAfter, nodeDelBalanceBefore - amountToDeposit, "NodeDelegator balance did not increase");

        assertEq(ethX.balanceOf(mockLRTDepositPool), amountToDeposit, "LRTDepositPool balance did not increase");
    }

    function test_TransferETHBackToLRTDepositPool() external {
        uint256 amountToDeposit = 3 ether;

        vm.deal(address(nodeDel), 100 ether);
        uint256 nodeDelBalanceBefore = address(nodeDel).balance;

        // transfer funds in NodeDelegator to to LRTDepositPool
        vm.prank(manager);
        nodeDel.transferBackToLRTDepositPool(LRTConstants.ETH_TOKEN, amountToDeposit);

        uint256 nodeDelBalanceAfter = address(nodeDel).balance;

        assertLt(nodeDelBalanceAfter, nodeDelBalanceBefore, "NodeDelegator balance did not increase");
        assertEq(nodeDelBalanceAfter, nodeDelBalanceBefore - amountToDeposit, "NodeDelegator balance did not increase");

        assertEq(mockLRTDepositPool.balance, amountToDeposit, "LRTDepositPool balance did not increase");
    }
}

contract NodeDelegatorGetAssetBalances is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        vm.startPrank(bob);
        ethX.transfer(address(nodeDel), 10 ether);
        stETH.transfer(address(nodeDel), 5 ether);
        vm.stopPrank();

        // max approve nodeDelegator to deposit into strategy
        vm.startPrank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
        nodeDel.maxApproveToEigenStrategyManager(address(stETH));
        vm.stopPrank();
    }

    function test_GetAssetBalances() external {
        // deposit NodeDelegator balance into strategy
        vm.startPrank(manager);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        nodeDel.depositAssetIntoStrategy(address(stETH));
        vm.stopPrank();

        // get asset balances in strategies
        (address[] memory assets, uint256[] memory assetBalances) = nodeDel.getAssetBalances();

        assertEq(assets.length, 2, "Incorrect number of assets");
        assertEq(assets[0], address(ethX), "Incorrect asset");
        assertEq(assets[1], address(stETH), "Incorrect asset");
        assertEq(assetBalances.length, 2, "Incorrect number of asset balances");
        assertEq(assetBalances[0], mockUserUnderlyingViewBalance, "Incorrect asset balance for ethX");
        assertEq(assetBalances[1], mockUserUnderlyingViewBalance, "Incorrect asset balance for stETH");
    }
}

contract NodeDelegatorGetAssetBalance is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        // sends token to nodeDelegator so it can deposit it into the strategy
        vm.prank(bob);
        ethX.transfer(address(nodeDel), 6 ether);

        // max approve nodeDelegator to deposit into strategy
        vm.prank(manager);
        nodeDel.maxApproveToEigenStrategyManager(address(ethX));
    }

    function test_GetAssetBalance() external {
        // deposit NodeDelegator balance into strategy
        vm.startPrank(manager);
        nodeDel.depositAssetIntoStrategy(address(ethX));
        vm.stopPrank();

        // get asset balances in strategies
        (uint256 ethXNodeDelBalance) = nodeDel.getAssetBalance(address(ethX));

        assertEq(ethXNodeDelBalance, mockUserUnderlyingViewBalance, "Incorrect asset balance");
    }
}

contract NodeDelegatorGetETHEigenPodBalance is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        vm.prank(manager);
        nodeDel.createEigenPod();

        // add ETH to nodeDelegator so it can deposit it into the EigenPodManager
        vm.deal(address(nodeDel), 1000 ether);

        // stake ETH in EigenPodManager
        vm.prank(operator);
        nodeDel.stake32Eth(hex"", hex"", hex"");
    }

    function test_GetETHEigenPodBalance() external {
        uint256 ethEigenPodBalance = nodeDel.getETHEigenPodBalance();
        assertEq(ethEigenPodBalance, 32 ether, "Incorrect ETH balance in EigenPod");
    }
}

contract NodeDelegatorStakeETH is NodeDelegatorTest {
    uint256 public amount;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        amount = 32 ether;

        vm.prank(manager);
        nodeDel.createEigenPod();

        // add ETH to nodeDelegator so it can deposit it into the EigenPodManager
        vm.deal(address(nodeDel), amount);
    }

    function test_revertWhenCallerIsNotLRTOperator() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigOperator.selector);
        nodeDel.stake32Eth(hex"", hex"", hex"");
        vm.stopPrank();
    }

    function test_stakeETH() external {
        uint256 nodeDelBalanceBefore = address(nodeDel).balance;
        uint256 ethEigenPodBalanceBefore = nodeDel.getETHEigenPodBalance();

        vm.prank(operator);
        nodeDel.stake32Eth(hex"", hex"", hex"");

        uint256 nodeDelBalanceAfter = address(nodeDel).balance;

        assertLt(nodeDelBalanceAfter, nodeDelBalanceBefore, "NodeDelegator balance did not increase");
        assertEq(nodeDelBalanceAfter, nodeDelBalanceBefore - amount, "NodeDelegator balance did not increase");

        uint256 ethEigenPodBalance = nodeDel.getETHEigenPodBalance();
        assertEq(ethEigenPodBalance, amount + ethEigenPodBalanceBefore, "Incorrect ETH balance in EigenPod");

        uint256 stakedButUnverifiedNativeETH = nodeDel.stakedButUnverifiedNativeETH();
        assertEq(stakedButUnverifiedNativeETH, amount, "Incorrect staked but not verified ETH");
    }
}

contract NodeDelegatorPause is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));
    }

    function test_RevertWhenCallerIsNotLRTManager() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigManager.selector);
        nodeDel.pause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsAlreadyPaused() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.expectRevert("Pausable: paused");
        nodeDel.pause();

        vm.stopPrank();
    }

    function test_Pause() external {
        vm.startPrank(manager);
        nodeDel.pause();

        vm.stopPrank();

        assertTrue(nodeDel.paused(), "Contract is not paused");
    }
}

contract NodeDelegatorUnpause is NodeDelegatorTest {
    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        vm.startPrank(manager);
        nodeDel.pause();
        vm.stopPrank();
    }

    function test_RevertWhenCallerIsNotLRTAdmin() external {
        vm.startPrank(alice);
        vm.expectRevert(ILRTConfig.CallerNotLRTConfigAdmin.selector);
        nodeDel.unpause();
        vm.stopPrank();
    }

    function test_RevertWhenContractIsNotPaused() external {
        vm.startPrank(admin);
        nodeDel.unpause();

        vm.expectRevert("Pausable: not paused");
        nodeDel.unpause();

        vm.stopPrank();
    }

    function test_Unpause() external {
        vm.startPrank(admin);
        nodeDel.unpause();

        vm.stopPrank();

        assertFalse(nodeDel.paused(), "Contract is still paused");
    }
}

contract NodeDelegatorSendETHFromDepositPoolToNDC is NodeDelegatorTest {
    address public lrtDepositPool;
    uint256 public amount;

    function setUp() public override {
        super.setUp();
        nodeDel.initialize(address(lrtConfig));

        amount = 32 ether;

        // add ETH to LRTDepositPool
        lrtDepositPool = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        vm.deal(lrtDepositPool, amount);
    }

    function test_RevertWhenCallerIsNotLRTDepositPool() external {
        vm.startPrank(alice);
        vm.expectRevert(INodeDelegator.InvalidETHSender.selector);
        nodeDel.sendETHFromDepositPoolToNDC();
        vm.stopPrank();
    }

    function test_SendETHFromDepositPoolToNDC() external {
        assertEq(address(nodeDel).balance, 0, "Incorrect balance before sending ETH from LRTDepositPool");
        // it is callable by LRTDepositPool
        vm.startPrank(lrtDepositPool);
        expectEmit();
        emit ETHDepositFromDepositPool(amount);
        nodeDel.sendETHFromDepositPoolToNDC{ value: amount }();
        vm.stopPrank();

        assertEq(address(nodeDel).balance, amount, "Incorrect balance after sending ETH from LRTDepositPool");
    }
}
