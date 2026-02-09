// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { LRTConfigRoleChecker, ILRTConfig } from "./utils/LRTConfigRoleChecker.sol";
import { WadMath } from "./utils/WadMath.sol";

import { IRSETH } from "./interfaces/IRSETH.sol";
import { IPriceFetcher } from "./interfaces/IPriceFetcher.sol";
import { ILRTOracle } from "./interfaces/ILRTOracle.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IPausable {
    function pause() external;
    function paused() external view returns (bool);
}

/// @title LRTOracle Contract
/// @notice oracle contract that calculates the exchange rate of assets
contract LRTOracle is ILRTOracle, LRTConfigRoleChecker, Initializable {
    using WadMath for uint256;

    mapping(address asset => address priceOracle) public override assetPriceOracle;

    uint256 public override rsETHPrice;
    uint256 public pricePercentageLimit;
    uint256 public highestRsethPrice;

    // Daily fee minting limit variables
    uint256 public currentPeriodMintedFeeAmount;
    uint256 public feePeriodStartTime;
    uint256 public maxFeeMintAmountPerDay;

    /// @notice New variable added for pausable functionality
    bool public paused;

    modifier onlySupportedOracle(address asset) {
        if (assetPriceOracle[asset] == address(0)) {
            revert AssetOracleNotSupported();
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
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

    /// @notice Initializes the contract with a fee period start time
    /// @param _feePeriodStartTime The start time of the fee period
    function reinitialize(uint256 _feePeriodStartTime) external reinitializer(2) onlyLRTManager {
        if (_feePeriodStartTime > block.timestamp || _feePeriodStartTime <= block.timestamp - 1 days) {
            revert PeriodStartTimeShouldBeWithin24Hours();
        }

        feePeriodStartTime = _feePeriodStartTime;
        emit FeePeriodStartTimeSet(_feePeriodStartTime);
    }

    /*//////////////////////////////////////////////////////////////
                            write functions
    //////////////////////////////////////////////////////////////*/

    /// @notice updates RSETH/ETH exchange rate
    /// @dev calculates rsETH price based on stakedAsset value received from EigenLayer
    function updateRSETHPrice() public whenNotPaused {
        _updateRsETHPrice();
    }

    /// @dev update rsETH price as an manager account
    /// @dev main benefit is to be able to update the price in case of the price going above the threshold
    /// @dev only LRT manager is allowed to call this function
    function updateRSETHPriceAsManager() external onlyLRTManager {
        _updateRsETHPrice();
    }

    /// @dev add/update the price oracle of any asset
    /// @dev only onlyLRTAdmin is allowed
    /// @param asset asset address for which oracle price needs to be added/updated
    function updatePriceOracleForValidated(address asset, address priceOracle) external onlyLRTAdmin {
        // Sanity check: oracle price must have precision between 1e16 and 1e19
        uint256 price = IPriceFetcher(priceOracle).getAssetPrice(asset);
        if (price > 1e19 || price < 1e16) {
            revert InvalidPriceOracle();
        }
        updatePriceOracleFor(asset, priceOracle);
    }

    /// @dev add/update the price oracle of any asset
    /// @dev only onlyLRTAdmin is allowed
    /// @param asset asset address for which oracle price needs to be added/updated
    function updatePriceOracleFor(address asset, address priceOracle) public onlyLRTAdmin {
        if (lrtConfig.isSupportedAsset(asset)) {
            UtilLib.checkNonZeroAddress(priceOracle);
        }
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

    /// @dev set the maximum fee minting amount per day. Only onlyLRTManager is allowed
    /// @param _maxFeeMintAmountPerDay maximum amount of fee that can be minted per day
    function setMaxFeeMintAmountPerDay(uint256 _maxFeeMintAmountPerDay) external onlyLRTManager {
        maxFeeMintAmountPerDay = _maxFeeMintAmountPerDay;
        emit MaxFeeMintAmountPerDayUpdated(_maxFeeMintAmountPerDay);
    }

    /// @dev Triggers stopped state. Contract must not be paused.
    function pause() external whenNotPaused onlyRole(LRTConstants.PAUSER_ROLE) {
        _pause();
    }

    /// @dev Returns to normal state. Contract must be paused.
    function unpause() external whenPaused onlyLRTAdmin {
        paused = false;
        emit Unpaused(msg.sender);
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

    /// @notice Gets the start timestamp of the current 24-hour fee minting period
    /// @return uint256 The start timestamp of the current 24-hour period, calculated from the fee period start time
    function getCurrentPeriodStartTime() public view returns (uint256) {
        // Calculate the full (complete) days elapsed since the period start time (floors the result)
        uint256 daysElapsed = (block.timestamp - feePeriodStartTime) / 1 days;
        return feePeriodStartTime + daysElapsed * 1 days;
    }

    /// @notice Gets the remaining daily fee minting limit for the current period
    /// @return uint256 The remaining daily fee minting limit
    function remainingDailyFeeMintLimit() external view returns (uint256) {
        if (maxFeeMintAmountPerDay == 0) return 0;

        // If we're on a new day but no mint has occurred yet, treat currentPeriodMintedAmount as 0
        uint256 effectiveDailyFeeMintAmount =
            (block.timestamp >= feePeriodStartTime + 1 days) ? 0 : currentPeriodMintedFeeAmount;

        return
            maxFeeMintAmountPerDay > effectiveDailyFeeMintAmount
                ? maxFeeMintAmountPerDay - effectiveDailyFeeMintAmount
                : 0;
    }

    /// @notice Returns the timestamp at which the current effective daily fee minting limit period ends,
    /// accounting for any skipped days during which no fee minting occurred
    /// @dev A fee mint executed at exactly this timestamp is counted towards the next period's fee minting limit
    /// @return uint256 The timestamp at which the effective current fee minting limit period ends
    function getNextDailyLimitResetTimestamp() external view returns (uint256) {
        return getCurrentPeriodStartTime() + 1 days;
    }

    /*//////////////////////////////////////////////////////////////
                            internal functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks and updates daily fee minting limits
    /// @param feeAmount The amount of fee to be minted
    function _checkAndUpdateDailyFeeMintLimit(uint256 feeAmount) internal {
        // Reset the period if it's unset or a day has passed
        if (block.timestamp >= feePeriodStartTime + 1 days) {
            currentPeriodMintedFeeAmount = 0;
            feePeriodStartTime = getCurrentPeriodStartTime();
        }

        // Check if minting would exceed the daily limit
        if (currentPeriodMintedFeeAmount + feeAmount > maxFeeMintAmountPerDay) {
            revert DailyFeeMintLimitExceeded(currentPeriodMintedFeeAmount + feeAmount, maxFeeMintAmountPerDay);
        }

        currentPeriodMintedFeeAmount += feeAmount;
    }

    /// @dev Internal function to update rsETH price
    // solhint-disable-next-line code-complexity
    function _updateRsETHPrice() internal {
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

        // get total ETH in the protocol (normalized to 1e18)
        uint256 totalETHInProtocol = _getTotalEthInProtocol();

        // calculate previousTVL using rsethSupply multiplied by rsETHPrice
        uint256 previousTVL = rsethSupply.mulWad(rsETHPrice);

        IPausable lrtDepositPool = IPausable(lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL));
        IPausable withdrawalManager = IPausable(lrtConfig.getContract(LRTConstants.LRT_WITHDRAW_MANAGER));

        // determine if the protocol is active (not paused)
        bool protocolPaused = lrtDepositPool.paused() || withdrawalManager.paused() || paused;

        // only take fee if TVL increased and protocol is not paused
        uint256 protocolFeeInETH = 0;
        if (!protocolPaused && totalETHInProtocol > previousTVL) {
            uint256 rewardAmount = totalETHInProtocol - previousTVL;
            protocolFeeInETH = (rewardAmount * lrtConfig.protocolFeeInBPS()) / 10_000;
        }

        // compute new rsETH price based on total ETH minus fee
        uint256 newRsETHPrice = (totalETHInProtocol - protocolFeeInETH).divWad(rsethSupply);

        if (newRsETHPrice > highestRsethPrice) {
            // check if the price is above the threshold
            uint256 priceDifference = newRsETHPrice - highestRsethPrice;
            // pricePercentageLimit is in 1e18 precision (100% = 1e18, 1% = 1e16)
            bool isPriceIncreaseOffLimit =
                pricePercentageLimit > 0 && priceDifference > pricePercentageLimit.mulWad(highestRsethPrice);

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
            // normalizing to 1e18
            bool isPriceDecreaseOffLimit =
                pricePercentageLimit > 0 && diff > pricePercentageLimit.mulWad(highestRsethPrice);

            // if price decrease is off limit, pause the protocol (unless it's already paused)
            if (isPriceDecreaseOffLimit) {
                if (!lrtDepositPool.paused()) lrtDepositPool.pause();
                if (!withdrawalManager.paused()) withdrawalManager.pause();
                _pause();
                return;
            }

            // if price has decreased compared to the previous price, emit an event to reflect that
            if (previousPrice > newRsETHPrice) {
                emit RsETHPriceDecrease(newRsETHPrice, previousPrice);
            }

            // emit an event to notify that the price is currently below the peak (all time high) price
            emit RsETHPriceBelowPeak(highestRsethPrice, newRsETHPrice);
        }

        // update highest price if new price exceeds it
        if (newRsETHPrice > highestRsethPrice) {
            highestRsethPrice = newRsETHPrice;
        }

        // mint protocol fee as rsETH if there's a fee to take
        if (protocolFeeInETH > 0) {
            // Calculate rsETH amount to mint as protocol fee
            uint256 rsethAmountToMintAsProtocolFee = protocolFeeInETH.divWad(newRsETHPrice);

            _checkAndUpdateDailyFeeMintLimit(rsethAmountToMintAsProtocolFee);
            if (rsethAmountToMintAsProtocolFee > 0) {
                address treasury = lrtConfig.getContract(LRTConstants.PROTOCOL_TREASURY);
                IRSETH(rsETHTokenAddress).mint(treasury, rsethAmountToMintAsProtocolFee);
                emit FeeMinted(treasury, rsethAmountToMintAsProtocolFee);
            }
        } else {
            _checkAndUpdateDailyFeeMintLimit(0);
        }

        rsETHPrice = newRsETHPrice;

        emit RsETHPriceUpdate(rsETHPrice, previousPrice);
    }

    /// @dev Internal function to pause the contract
    function _pause() internal {
        if (paused) return;
        paused = true;
        emit Paused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            private functions
    //////////////////////////////////////////////////////////////*/

    /// @notice get total ETH in protocol
    /// @return totalETHInProtocol total ETH in protocol (normalized to 1e18)
    function _getTotalEthInProtocol() private view returns (uint256 totalETHInProtocol) {
        address lrtDepositPoolAddr = lrtConfig.getContract(LRTConstants.LRT_DEPOSIT_POOL);
        address[] memory supportedAssets = lrtConfig.getSupportedAssetList();
        uint256 supportedAssetCount = supportedAssets.length;

        for (uint16 assetIdx; assetIdx < supportedAssetCount;) {
            address asset = supportedAssets[assetIdx];
            // assetER is in 1e18 precision (1.0 = 1e18)
            uint256 assetER = getAssetPrice(asset);
            // totalAssetAmt is in 1e18 precision (standard token decimals)
            uint256 totalAssetAmt = ILRTDepositPool(lrtDepositPoolAddr).getTotalAssetDeposits(asset);

            totalETHInProtocol += totalAssetAmt.mulWad(assetER);

            unchecked {
                ++assetIdx;
            }
        }
    }
}
