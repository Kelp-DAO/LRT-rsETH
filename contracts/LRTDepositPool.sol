// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";

import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";
import { IRSETH } from "./interfaces/IRSETH.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { INodeDelegator } from "./interfaces/INodeDelegator.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { ILRTUnstakingVault } from "./interfaces/ILRTUnstakingVault.sol";
import { ILRTConverter } from "./interfaces/ILRTConverter.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IDelegationManager } from "./external/eigenlayer/interfaces/IDelegationManager.sol";

import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title LRTDepositPool - Deposit Pool Contract for LSTs
/// @notice Handles LST asset deposits
contract LRTDepositPool is ILRTDepositPool, LRTConfigRoleChecker, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public maxNodeDelegatorLimit;
    uint256 public minAmountToDeposit;

    mapping(address => uint256) public isNodeDelegator; // 0: not a node delegator, 1: is a node delegator
    address[] public nodeDelegatorQueue;

    /// @notice maximum amount that can be ignored
    uint256 public maxNegligibleAmount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        __Pausable_init();
        __ReentrancyGuard_init();
        maxNodeDelegatorLimit = 10;
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /*//////////////////////////////////////////////////////////////
                        receive functions
    //////////////////////////////////////////////////////////////*/

    receive() external payable { }

    /// @dev receive from RewardReceiver
    function receiveFromRewardReceiver() external payable { }

    /// @dev receive from LRTConverter
    function receiveFromLRTConverter() external payable { }

    /// @dev receive from NodeDelegator
    function receiveFromNodeDelegator() external payable { }

    /*//////////////////////////////////////////////////////////////
                            user interactions
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows user to deposit ETH to the protocol
    /// @param minRSETHAmountExpected Minimum amount of rseth to receive
    /// @param referralId referral id
    function depositETH(
        uint256 minRSETHAmountExpected,
        string calldata referralId
    )
        external
        payable
        nonReentrant
        whenNotPaused
    {
        // checks
        uint256 rsethAmountToMint = _beforeDeposit(LRTConstants.ETH_TOKEN, msg.value, minRSETHAmountExpected);

        // interactions
        _mintRsETH(rsethAmountToMint);

        emit ETHDeposit(msg.sender, msg.value, rsethAmountToMint, referralId);
    }

    /// @notice helps user stake LST to the protocol
    /// @param asset LST asset address to stake
    /// @param depositAmount LST asset amount to stake
    /// @param minRSETHAmountExpected Minimum amount of rseth to receive
    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountExpected,
        string calldata referralId
    )
        external
        nonReentrant
        whenNotPaused
        onlySupportedAsset(asset)
    {
        // checks
        uint256 rsethAmountToMint = _beforeDeposit(asset, depositAmount, minRSETHAmountExpected);

        // interactions
        IERC20(asset).safeTransferFrom(msg.sender, address(this), depositAmount);
        _mintRsETH(rsethAmountToMint);

        emit AssetDeposit(msg.sender, asset, depositAmount, rsethAmountToMint, referralId);
    }

    /*//////////////////////////////////////////////////////////////
                        Fund movement functions
    //////////////////////////////////////////////////////////////*/

    /// @notice swap ETH for LST asset which is accepted by LRTDepositPool
    /// @dev use LRTOracle to get price for toToken. Only callable by LRT manager
    /// @param toAsset Asset address to swap to
    /// @param minToAssetAmount Minimum asset amount to swap to
    function swapETHForAssetWithinDepositPool(
        address toAsset,
        uint256 minToAssetAmount
    )
        external
        payable
        onlyLRTManager
        onlySupportedAsset(toAsset)
    {
        // checks
        uint256 ethAmountSent = msg.value;

        uint256 returnAmount = getSwapETHToAssetReturnAmount(toAsset, ethAmountSent);

        if (returnAmount < minToAssetAmount || IERC20(toAsset).balanceOf(address(this)) < returnAmount) {
            revert NotEnoughAssetToTransfer();
        }

        // interactions
        IERC20(toAsset).transfer(msg.sender, returnAmount);

        emit ETHSwappedForLST(ethAmountSent, toAsset, returnAmount);
    }

    /// @notice transfers asset lying in this DepositPool to node delegator contract
    /// @dev only callable by LRT Operator
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param asset Asset address
    /// @param amount Asset amount to transfer
    function transferAssetToNodeDelegator(
        uint256 ndcIndex,
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        onlyLRTOperator
        onlySupportedAsset(asset)
    {
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        IERC20(asset).safeTransfer(nodeDelegator, amount);
    }

    /// @notice transfers ETH lying in this DepositPool to node delegator contract
    /// @dev only callable by LRT Operator
    /// @param ndcIndex Index of NodeDelegator contract address in nodeDelegatorQueue
    /// @param amount ETH amount to transfer
    function transferETHToNodeDelegator(uint256 ndcIndex, uint256 amount) external nonReentrant onlyLRTOperator {
        address nodeDelegator = nodeDelegatorQueue[ndcIndex];
        INodeDelegator(nodeDelegator).sendETHFromDepositPoolToNDC{ value: amount }();
        emit EthTransferred(nodeDelegator, amount);
    }

    /// @notice transfers asset lying in this DepositPool to LRTUnstakingVault contract
    /// @dev only callable by LRT Operator
    /// @param asset Asset address
    /// @param amount Asset amount to transfer
    function transferAssetToLRTUnstakingVault(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        onlyLRTOperator
        onlySupportedAsset(asset)
    {
        address lrtUnstakingVault = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        IERC20(asset).safeTransfer(lrtUnstakingVault, amount);
    }

    /// @notice transfers ETH lying in this DepositPool to nLRTUnstakingVault contract
    /// @dev only callable by LRT Operator
    /// @param amount ETH amount to transfer
    function transferETHToLRTUnstakingVault(uint256 amount) external nonReentrant onlyLRTOperator {
        address lrtUnstakingVault = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        ILRTUnstakingVault(lrtUnstakingVault).receiveFromLRTDepositPool{ value: amount }();
        emit EthTransferred(lrtUnstakingVault, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    Setters / Update Functions
    //////////////////////////////////////////////////////////////*/

    /// @notice maximum amount that can be ignored
    /// @dev only callable by LRT admin
    /// @param maxNegligibleAmount_ Maximum amount that can be ignored
    function setMaxNegligibleAmount(uint256 maxNegligibleAmount_) external onlyLRTAdmin {
        maxNegligibleAmount = maxNegligibleAmount_;
        emit MaxNegligibleAmountUpdated(maxNegligibleAmount_);
    }

    /// @notice update min amount to deposit
    /// @dev only callable by LRT admin
    /// @param minAmountToDeposit_ Minimum amount to deposit
    function setMinAmountToDeposit(uint256 minAmountToDeposit_) external onlyLRTAdmin {
        minAmountToDeposit = minAmountToDeposit_;
        emit MinAmountToDepositUpdated(minAmountToDeposit_);
    }

    /// @notice update max node delegator count
    /// @dev only callable by LRT admin
    /// @param maxNodeDelegatorLimit_ Maximum count of node delegator
    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit_) external onlyLRTAdmin {
        if (maxNodeDelegatorLimit_ < nodeDelegatorQueue.length) {
            revert InvalidMaximumNodeDelegatorLimit();
        }

        maxNodeDelegatorLimit = maxNodeDelegatorLimit_;
        emit MaxNodeDelegatorLimitUpdated(maxNodeDelegatorLimit);
    }

    /// @notice add new node delegator contract addresses
    /// @dev only callable by LRT admin
    /// @param nodeDelegatorContracts Array of NodeDelegator contract addresses
    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContracts) external onlyLRTAdmin {
        uint256 length = nodeDelegatorContracts.length;
        if (nodeDelegatorQueue.length + length > maxNodeDelegatorLimit) {
            revert MaximumNodeDelegatorLimitReached();
        }

        for (uint256 i; i < length;) {
            UtilLib.checkNonZeroAddress(nodeDelegatorContracts[i]);

            // check if node delegator contract is already added and add it if not
            if (isNodeDelegator[nodeDelegatorContracts[i]] == 0) {
                nodeDelegatorQueue.push(nodeDelegatorContracts[i]);
            }

            isNodeDelegator[nodeDelegatorContracts[i]] = 1;

            unchecked {
                ++i;
            }
        }

        emit NodeDelegatorAddedinQueue(nodeDelegatorContracts);
    }

    /// @notice remove node delegator contract address from queue
    /// @dev only callable by LRT admin
    /// @param nodeDelegatorAddress NodeDelegator contract address
    function removeNodeDelegatorContractFromQueue(address nodeDelegatorAddress) external onlyLRTAdmin {
        _removeNodeDelegatorContractFromQueue(nodeDelegatorAddress);
    }

    /// @notice remove many node delegator contracts from queue
    /// @dev only callable by LRT admin
    /// @param nodeDelegatorContracts Array of NodeDelegator contract addresses
    function removeManyNodeDelegatorContractsFromQueue(address[] calldata nodeDelegatorContracts)
        external
        onlyLRTAdmin
    {
        uint256 length = nodeDelegatorContracts.length;
        for (uint256 i; i < length;) {
            _removeNodeDelegatorContractFromQueue(nodeDelegatorContracts[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external onlyLRTManager {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused
    function unpause() external onlyLRTAdmin {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                    other write functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Approves the maximum amount of an asset to the LRTConverter contract
    /// @dev only supported assets can be deposited and only called by the LRT manager
    /// @param asset the asset to approve
    function maxApproveToLRTConverter(address asset) external onlySupportedAsset(asset) onlyLRTManager {
        address lrtConverterAddress = lrtConfig.getContract(LRTConstants.LRT_CONVERTER);
        IERC20(asset).approve(lrtConverterAddress, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice gets the total asset present in protocol
    /// @param asset Asset address
    /// @return totalAssetDeposit total asset present in protocol
    function getTotalAssetDeposits(address asset) public view override returns (uint256 totalAssetDeposit) {
        (
            uint256 assetLyingInDepositPool,
            uint256 assetLyingInNDCs,
            int256 assetStakedInEigenLayer,
            uint256 assetUnstakingFromEigenLayer,
            uint256 assetLyingInConverter,
            uint256 assetLyingUnstakingVault
        ) = getAssetDistributionData(asset);
        uint256 effectiveAssetWithEigenLayer =
            SafeCast.toUint256(assetStakedInEigenLayer + SafeCast.toInt256(assetUnstakingFromEigenLayer));
        return (
            assetLyingInDepositPool + assetLyingInNDCs + effectiveAssetWithEigenLayer + assetLyingInConverter
                + assetLyingUnstakingVault
        );
    }

    /// @notice gets the current limit of asset deposit
    /// @param asset Asset address
    /// @return currentLimit Current limit of asset deposit
    function getAssetCurrentLimit(address asset) public view override returns (uint256) {
        uint256 totalAssetDeposits = getTotalAssetDeposits(asset);
        if (totalAssetDeposits > lrtConfig.depositLimitByAsset(asset)) {
            return 0;
        }

        return lrtConfig.depositLimitByAsset(asset) - totalAssetDeposits;
    }

    /// @dev get node delegator queue
    /// @return nodeDelegatorQueue Array of node delegator contract addresses
    function getNodeDelegatorQueue() external view override returns (address[] memory) {
        return nodeDelegatorQueue;
    }

    /// @dev provides asset amount distribution data among depositPool, NDCs and eigenLayer
    /// @param asset the asset to get the total amount of
    /// @return assetLyingInDepositPool asset amount lying in this LRTDepositPool contract
    /// @return assetLyingInNDCs asset amount sum lying in all NDC contract
    /// @return assetStakedInEigenLayer asset amount deposited in eigen layer strategies through all NDCs
    /// @return assetUnstakingFromEigenLayer asset amount in delayed withdrawal from eigen layer strategies through all
    /// NDCs
    /// @return assetLyingInConverter asset value lying in converter
    /// @return assetLyingUnstakingVault asset amount lying in UnstakingVault
    function getAssetDistributionData(address asset)
        public
        view
        override
        onlySupportedAsset(asset)
        returns (
            uint256 assetLyingInDepositPool,
            uint256 assetLyingInNDCs,
            int256 assetStakedInEigenLayer,
            uint256 assetUnstakingFromEigenLayer,
            uint256 assetLyingInConverter,
            uint256 assetLyingUnstakingVault
        )
    {
        if (asset == LRTConstants.ETH_TOKEN) {
            return getETHDistributionData();
        }
        assetLyingInDepositPool = IERC20(asset).balanceOf(address(this));

        uint256 ndcsCount = nodeDelegatorQueue.length;
        for (uint256 i; i < ndcsCount;) {
            assetLyingInNDCs += IERC20(asset).balanceOf(nodeDelegatorQueue[i]);
            if (!INodeDelegator(nodeDelegatorQueue[i]).hasAllWithdrawalsAccounted()) {
                revert NodeDelegatorHasUnaccountedWithdrawals();
            }
            assetStakedInEigenLayer += SafeCast.toInt256(INodeDelegator(nodeDelegatorQueue[i]).getAssetBalance(asset));

            unchecked {
                ++i;
            }
        }

        address lrtUnstakingVault = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        assetUnstakingFromEigenLayer = ILRTUnstakingVault(lrtUnstakingVault).getAssetsUnstaking(asset);
        assetLyingInConverter = 0; //assets in converter are accounted in there eth value => getETHDistributionData
        assetLyingUnstakingVault = IERC20(asset).balanceOf(lrtUnstakingVault);
    }

    /// @dev provides ETH amount distribution data among depositPool, NDCs and eigenLayer
    /// @dev rewards are not accounted here
    /// it will automatically be accounted once it is moved from feeReceiver/rewardReceiver to depositPool
    function getETHDistributionData()
        public
        view
        override
        returns (
            uint256 ethLyingInDepositPool,
            uint256 ethLyingInNDCs,
            int256 ethStakedInEigenLayer,
            uint256 ethUnstakingFromEigenLayer,
            uint256 ethLyingInConverter,
            uint256 ethLyingInUnstakingVault
        )
    {
        ethLyingInDepositPool = address(this).balance;

        uint256 ndcsCount = nodeDelegatorQueue.length;
        for (uint256 i; i < ndcsCount;) {
            ethLyingInNDCs += nodeDelegatorQueue[i].balance;
            if (!INodeDelegator(nodeDelegatorQueue[i]).hasAllWithdrawalsAccounted()) {
                revert NodeDelegatorHasUnaccountedWithdrawals();
            }
            ethStakedInEigenLayer += INodeDelegator(nodeDelegatorQueue[i]).getEffectivePodShares();
            unchecked {
                ++i;
            }
        }

        address lrtUnstakingVault = lrtConfig.getContract(LRTConstants.LRT_UNSTAKING_VAULT);
        ethUnstakingFromEigenLayer = ILRTUnstakingVault(lrtUnstakingVault).getAssetsUnstaking(LRTConstants.ETH_TOKEN);

        address lrtConverter = lrtConfig.getContract(LRTConstants.LRT_CONVERTER);
        ethLyingInConverter = ILRTConverter(lrtConverter).ethValueInWithdrawal();

        ethLyingInUnstakingVault = lrtUnstakingVault.balance;
    }

    /// @notice View amount of rsETH to mint for given asset amount
    /// @param asset Asset address
    /// @param amount Asset amount
    /// @return rsethAmountToMint Amount of rseth to mint
    function getRsETHAmountToMint(
        address asset,
        uint256 amount
    )
        public
        view
        override
        returns (uint256 rsethAmountToMint)
    {
        // setup oracle contract
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);

        // calculate rseth amount to mint based on asset amount and asset exchange rate
        rsethAmountToMint = (amount * lrtOracle.getAssetPrice(asset)) / lrtOracle.rsETHPrice();
    }

    /// @notice get return amount for swapping ETH to asset that is accepted by LRTDepositPool
    /// @dev use LRTOracle to get price for toToken
    /// @param toAsset Asset address to swap to
    /// @param ethAmountToSend Eth amount to swap from
    /// @return returnAmount Return amount of toAsset
    function getSwapETHToAssetReturnAmount(
        address toAsset,
        uint256 ethAmountToSend
    )
        public
        view
        returns (uint256 returnAmount)
    {
        address lrtOracleAddress = lrtConfig.getContract(LRTConstants.LRT_ORACLE);
        ILRTOracle lrtOracle = ILRTOracle(lrtOracleAddress);

        uint256 ethPricePerUint = 1e18;

        return ethPricePerUint * ethAmountToSend / lrtOracle.getAssetPrice(toAsset);
    }

    /*//////////////////////////////////////////////////////////////
                          internal functions
    //////////////////////////////////////////////////////////////*/

    /// @notice internal function to remove node delegator contract address from queue
    /// @param nodeDelegatorAddress NodeDelegator contract address
    function _removeNodeDelegatorContractFromQueue(address nodeDelegatorAddress) internal {
        // 1. check if node delegator contract is in queue and find Index
        uint256 ndcIndex = _getNDCIndex(nodeDelegatorAddress);

        // 2. revert if node delegator contract has any asset balances.
        // 2.1 check if NDC has native ETH balance in eigen layer or/and in itself.
        _checkResidueEthBalance(nodeDelegatorAddress);
        // 2.2  check if NDC has LST balance
        _checkResidueLSTBalance(nodeDelegatorAddress);

        // 3. remove node delegator contract from queue
        // 3.1 remove from isNodeDelegator mapping
        isNodeDelegator[nodeDelegatorAddress] = 0;
        // 3.2 remove from nodeDelegatorQueue
        nodeDelegatorQueue[ndcIndex] = nodeDelegatorQueue[nodeDelegatorQueue.length - 1];
        nodeDelegatorQueue.pop();

        emit NodeDelegatorRemovedFromQueue(nodeDelegatorAddress);
    }

    function _getNDCIndex(address nodeDelegatorAddress) internal view returns (uint256) {
        uint256 length = nodeDelegatorQueue.length;
        uint256 i;
        for (; i < length;) {
            if (nodeDelegatorQueue[i] == nodeDelegatorAddress) {
                return i;
            }
            unchecked {
                ++i;
            }
        }

        // If node delegator contract is not found in queue, revert
        revert NodeDelegatorNotFound();
    }

    /// @dev reverts if NDC has native ETH balance in eigen layer or in itself.
    function _checkResidueEthBalance(address nodeDelegatorAddress) internal view {
        if (
            INodeDelegator(nodeDelegatorAddress).stakedButUnverifiedNativeETH() > 0
                || INodeDelegator(nodeDelegatorAddress).getEffectivePodShares() != 0
                || address(nodeDelegatorAddress).balance > maxNegligibleAmount
        ) {
            revert NodeDelegatorHasETH();
        }
    }

    /// @dev reverts if NDC has LST balance
    function _checkResidueLSTBalance(address nodeDelegatorAddress) internal view {
        address[] memory supportedAssets = lrtConfig.getSupportedAssetList();
        uint256 supportedAssetsLength = supportedAssets.length;

        uint256 assetBalance;
        for (uint256 i; i < supportedAssetsLength; ++i) {
            if (supportedAssets[i] == LRTConstants.ETH_TOKEN) {
                // this function only checks for residual LST balance
                continue;
            }

            assetBalance = IERC20(supportedAssets[i]).balanceOf(nodeDelegatorAddress)
                + INodeDelegator(nodeDelegatorAddress).getAssetBalance(supportedAssets[i]);

            if (assetBalance > maxNegligibleAmount) {
                revert NodeDelegatorHasAssetBalance(supportedAssets[i], assetBalance);
            }
        }
    }

    function _beforeDeposit(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountExpected
    )
        private
        view
        returns (uint256 rsethAmountToMint)
    {
        if (depositAmount == 0 || depositAmount < minAmountToDeposit) {
            revert InvalidAmountToDeposit();
        }

        if (_checkIfDepositAmountExceedesCurrentLimit(asset, depositAmount)) {
            revert MaximumDepositLimitReached();
        }

        rsethAmountToMint = getRsETHAmountToMint(asset, depositAmount);

        if (rsethAmountToMint < minRSETHAmountExpected) {
            revert MinimumAmountToReceiveNotMet();
        }
    }

    /// @notice checks if deposit amount exceeds current limit
    /// @param asset Asset address
    /// @param amount Asset amount
    /// @return bool true if deposit amount exceeds current limit
    function _checkIfDepositAmountExceedesCurrentLimit(address asset, uint256 amount) internal view returns (bool) {
        uint256 totalAssetDeposits = getTotalAssetDeposits(asset);
        if (asset == LRTConstants.ETH_TOKEN) {
            return (totalAssetDeposits > lrtConfig.depositLimitByAsset(asset));
        }
        return (totalAssetDeposits + amount > lrtConfig.depositLimitByAsset(asset));
    }

    /// @dev private function to mint rseth
    /// @param rsethAmountToMint Amount of rseth minted
    function _mintRsETH(uint256 rsethAmountToMint) private {
        address rsethToken = lrtConfig.rsETH();
        // mint rseth for user
        IRSETH(rsethToken).mint(msg.sender, rsethAmountToMint);
    }
}
