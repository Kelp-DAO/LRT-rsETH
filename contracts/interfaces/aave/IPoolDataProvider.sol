// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title IPoolDataProvider
 * @author Aave
 * @notice Defines the basic interface for an Aave V3 Pool Data Provider
 */
interface IPoolDataProvider {
    /**
     * @notice Returns the configuration data of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return decimals The number of decimals of the reserve
     * @return ltv The ltv of the reserve
     * @return liquidationThreshold The liquidationThreshold of the reserve
     * @return liquidationBonus The liquidationBonus of the reserve
     * @return reserveFactor The reserveFactor of the reserve
     * @return usageAsCollateralEnabled True if the usage as collateral is enabled, false otherwise
     * @return borrowingEnabled True if borrowing is enabled, false otherwise
     * @return stableBorrowRateEnabled True if stable rate borrowing is enabled, false otherwise
     * @return isActive True if the reserve is active, false otherwise
     * @return isFrozen True if the reserve is frozen, false otherwise
     */
    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    /**
     * @notice Returns the caps parameters of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return borrowCap The borrow cap of the reserve
     * @return supplyCap The supply cap of the reserve
     */
    function getReserveCaps(address asset) external view returns (uint256 borrowCap, uint256 supplyCap);

    /**
     * @notice Returns the total supply of aTokens for a given asset
     * @param asset The address of the underlying asset of the reserve
     * @return The total supply of the aToken
     */
    function getATokenTotalSupply(address asset) external view returns (uint256);
}
