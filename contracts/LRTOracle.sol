// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";

import { IRSETH } from "./interfaces/IRSETH.sol";
import { IPriceFetcher } from "./interfaces/IPriceFetcher.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title LRTOracle Contract
/// @notice oracle contract that calculates the exchange rate of assets
contract LRTOracle is ILRTOracle, LRTConfigRoleChecker, Initializable {
    mapping(address asset => address priceOracle) public override assetPriceOracle;

    uint256 public override rsETHPrice;
    uint256 public pricePercentageLimit;

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
    function updateRSETHPrice() external {
        uint256 oldRsETHPrice = rsETHPrice;
        address rsETHTokenAddress = lrtConfig.rsETH();

        uint256 rsethSupply = IRSETH(rsETHTokenAddress).totalSupply(); // 1e18
        if (rsethSupply == 0) {
            rsETHPrice = 1 ether;
            return;
        }

        uint256 totalETHInProtocol = _getTotalEthInProtocol(); // 1e36
        uint256 protocolFeeInETH;
        {
            uint256 tempRsETHPrice = totalETHInProtocol / rsethSupply; // 1e18
            if (tempRsETHPrice > oldRsETHPrice) {
                uint256 increaseInRsEthPrice = tempRsETHPrice - oldRsETHPrice; // new_price - old_price // 1e18
                uint256 rewardInETH = (increaseInRsEthPrice * rsethSupply) / 1e18; // 1e18
                protocolFeeInETH = (rewardInETH * lrtConfig.protocolFeeInBPS()) / 10_000; // 1e18
            }
        }

        rsETHPrice = (totalETHInProtocol - (protocolFeeInETH * 1e18)) / rsethSupply; // 1e18
        uint256 rsethAmountToMintAsProtocolFee = (protocolFeeInETH * 1e18) / rsETHPrice; // 1e18

        if (_isNewPriceOffLimit(oldRsETHPrice, rsETHPrice)) revert RSETHPriceExceedsLimit();
        emit RsETHPriceUpdate(rsETHPrice, oldRsETHPrice);

        if (rsethAmountToMintAsProtocolFee == 0) return;
        address treasury = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
        IRSETH(rsETHTokenAddress).mint(treasury, rsethAmountToMintAsProtocolFee);
        emit FeeMinted(treasury, rsethAmountToMintAsProtocolFee);
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

    /// @dev set the price percentage limit
    /// @dev only onlyLRTAdmin is allowed
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

    /// @notice check if new price is off the price percentage limit
    /// @param oldPrice old price
    /// @param newPrice new price
    function _isNewPriceOffLimit(uint256 oldPrice, uint256 newPrice) private view returns (bool) {
        // if oldPrice == newPrice, then no need to check
        if (oldPrice == newPrice) return false;
        // if pricePercentageLimit is 0, then no need to check
        if (pricePercentageLimit == 0) return false;

        // calculate the difference between old and new price
        uint256 diff = (oldPrice > newPrice) ? oldPrice - newPrice : newPrice - oldPrice;
        uint256 percentage = (diff * 100) / oldPrice;
        return percentage > pricePercentageLimit;
    }
}
