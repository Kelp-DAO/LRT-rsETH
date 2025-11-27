// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { IRSETH } from "./interfaces/IRSETH.sol";
import { IPriceFetcher } from "./interfaces/IPriceFetcher.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IPausable {
    function pause() external;
}

/// @title LRTOracle Contract
/// @notice oracle contract that calculates the exchange rate of assets
contract LRTOracle is ILRTOracle, LRTConfigRoleChecker, Initializable {
    mapping(address asset => address priceOracle) public override assetPriceOracle;

    uint256 public override rsETHPrice;
    uint256 public pricePercentageLimit;
    uint256 public highestRsethPrice;

    // legacy variables
    uint256 public legacy_cooldownPeriodInTimestamp;
    uint256 public legacy_lastUpdatedCoolDownTimestamp;

    modifier onlySupportedOracle(address asset) {
        if (assetPriceOracle[asset] == address(0)) {
            revert AssetOracleNotSupported();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param lrtConfigAddr LRT config address
    function initialize(address lrtConfigAddr) external initializer {
        UtilLib.checkNonZeroAddress(lrtConfigAddr);
        lrtConfig = ILRTConfig(lrtConfigAddr);
        emit UpdatedLRTConfig(lrtConfigAddr);
    }

    /*//////////////////////////////////////////////////////////////
                            write functions
    //////////////////////////////////////////////////////////////*/

    /// @notice updates RSETH/ETH exchange rate
    /// @dev calculates based on stakedAsset value received from eigen layer
    function updateRSETHPrice() public {
        address rsETHTokenAddress = lrtConfig.rsETH();
        uint256 rsethSupply = IRSETH(rsETHTokenAddress).totalSupply();

        if (rsethSupply == 0) {
            rsETHPrice = 1 ether;
            highestRsethPrice = 1 ether;
            return;
        }

        if (highestRsethPrice == 0) {
            highestRsethPrice = rsETHPrice;
        }

        uint256 previousPrice = rsETHPrice;

        // get total ETH in the protocol
        uint256 totalETHInProtocol = _getTotalEthInProtocol();

        // calculate previousTVL using rsethSupply multiplied by rsETHPrice
        uint256 previousTVL = rsethSupply * rsETHPrice;

        // only take fee if TVL increased
        uint256 protocolFeeInETH = 0;
        if (totalETHInProtocol > previousTVL) {
            uint256 rewardAmount = totalETHInProtocol - previousTVL;
            protocolFeeInETH = (rewardAmount * lrtConfig.protocolFeeInBPS()) / 10_000;
        }

        // compute new rsETH price based on total ETH minus fee
        uint256 newRsETHPrice = (totalETHInProtocol - protocolFeeInETH) / rsethSupply;

        if (newRsETHPrice > highestRsethPrice) {
            // check if the price is above the threshold
            uint256 priceDifference = newRsETHPrice - highestRsethPrice;
            bool isPriceIncreaseOffLimit =
                pricePercentageLimit > 0 && priceDifference > (pricePercentageLimit * highestRsethPrice) / 1e18;

            // check if the price difference is above the threshold
            if (isPriceIncreaseOffLimit) {
                // if sender has a manager role, this doesn't revert.
                // if not, it reverts as price went above the threshold
                if (!IAccessControl(address(lrtConfig)).hasRole(LRTConstants.MANAGER, msg.sender)) {
                    revert PriceAboveDailyThreshold();
                }
            }
        }

        // downside protection — pause if price drops too far
        if (newRsETHPrice < highestRsethPrice) {
            uint256 diff = highestRsethPrice - newRsETHPrice;
            bool isPriceDecreaseOffLimit =
                pricePercentageLimit > 0 && diff > (pricePercentageLimit * highestRsethPrice) / 1e18;

            emit RsETHPriceDecrease(highestRsethPrice, newRsETHPrice);

            if (isPriceDecreaseOffLimit) {
                IPausable lrtDepositPool = IPausable(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
                IPausable withdrawalManager = IPausable(lrtConfig.getContract(LRTConstants.LRT_WITHDRAW_MANAGER));
                lrtDepositPool.pause();
                withdrawalManager.pause();
                return;
            }
        }

        // update highest price if new price exceeds it
        if (newRsETHPrice > highestRsethPrice) {
            highestRsethPrice = newRsETHPrice;
        }

        // mint protocol fee as rsETH if there's a fee to take
        if (protocolFeeInETH > 0) {
            uint256 rsethAmountToMintAsProtocolFee = protocolFeeInETH / newRsETHPrice;

            if (rsethAmountToMintAsProtocolFee > 0) {
                address treasury = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
                IRSETH(rsETHTokenAddress).mint(treasury, rsethAmountToMintAsProtocolFee);
                emit FeeMinted(treasury, rsethAmountToMintAsProtocolFee);
            }
        }

        rsETHPrice = newRsETHPrice;

        emit RsETHPriceUpdate(rsETHPrice, previousPrice);
    }

    /// @dev update rseth price as an manager account
    /// @dev main benefit is to be able to update the price in case of the price going above the threshold
    /// @dev only onlyLRTManager is allowed
    function updateRSETHPriceAsManager() external onlyLRTManager {
        updateRSETHPrice();
    }

    /// @dev add/update the price oracle of any asset
    /// @dev only onlyLRTAdmin is allowed
    /// @param asset asset address for which oracle price needs to be added/updated
    function updatePriceOracleForValidated(address asset, address priceOracle) external onlyLRTAdmin {
        //sanity check that oracle has 1e18 precision
        uint256 price = IPriceFetcher(priceOracle).getAssetPrice(asset);
        if (price > 1e19 || price < 1e18) {
            revert InvalidPriceOracle();
        }
        updatePriceOracleFor(asset, priceOracle);
    }

    /// @dev add/update the price oracle of any asset
    /// @dev only onlyLRTAdmin is allowed
    /// @param asset asset address for which oracle price needs to be added/updated
    function updatePriceOracleFor(address asset, address priceOracle) public onlyLRTAdmin {
        UtilLib.checkNonZeroAddress(priceOracle);
        assetPriceOracle[asset] = priceOracle;
        emit AssetPriceOracleUpdate(asset, priceOracle);
    }

    /// @dev set the price percentage limit. Only onlyLRTAdmin is allowed
    /// @dev PricePercentageLimit for 1% is 1e16
    /// @dev Price Percentage Limit for 100% is 1e18
    /// @param _pricePercentageLimit price percentage limit
    function setPricePercentageLimit(uint256 _pricePercentageLimit) external onlyLRTAdmin {
        pricePercentageLimit = _pricePercentageLimit;
        emit PricePercentageLimitUpdate(_pricePercentageLimit);
    }

    /*//////////////////////////////////////////////////////////////
                            view functions
    //////////////////////////////////////////////////////////////*/

    /// @notice Provides Asset/ETH exchange rate
    /// @dev reads from priceFetcher interface which may fetch price from any supported oracle
    /// @param asset the asset for which exchange rate is required
    /// @return assetPrice exchange rate of asset
    function getAssetPrice(address asset) public view onlySupportedOracle(asset) returns (uint256) {
        return IPriceFetcher(assetPriceOracle[asset]).getAssetPrice(asset);
    }

    /*//////////////////////////////////////////////////////////////
                            private functions
    //////////////////////////////////////////////////////////////*/

    /// @notice get total ETH in protocol
    /// @return totalETHInProtocol total ETH in protocol
    function _getTotalEthInProtocol() private view returns (uint256 totalETHInProtocol) {
        address lrtDepositPoolAddr = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        address[] memory supportedAssets = lrtConfig.getSupportedAssetList();
        uint256 supportedAssetCount = supportedAssets.length;

        for (uint16 assetIdx; assetIdx < supportedAssetCount;) {
            address asset = supportedAssets[assetIdx];
            uint256 assetER = getAssetPrice(asset);
            uint256 totalAssetAmt = ILRTDepositPool(lrtDepositPoolAddr).getTotalAssetDeposits(asset);
            totalETHInProtocol += totalAssetAmt * assetER;

            unchecked {
                ++assetIdx;
            }
        }
    }
}
