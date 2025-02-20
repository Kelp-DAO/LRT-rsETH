// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTConfig {
    // Errors
    error ValueAlreadyInUse();
    error AssetAlreadySupported();
    error AssetNotSupported();
    error CallerNotLRTConfigAdmin();
    error CallerNotLRTConfigManager();
    error CallerNotLRTConfigOperator();
    error CallerNotLRTConfigAllowedRole(string role);
    error CannotUpdateStrategyAsItHasFundsNDCFunds(address ndc, uint256 amount);
    error InvalidMaxRewardAmount();

    // Events
    event SetToken(bytes32 key, address indexed tokenAddr);
    event SetContract(bytes32 key, address indexed contractAddr);
    event AddedNewSupportedAsset(address indexed asset, uint256 depositLimit);
    event RemovedSupportedAsset(address indexed asset);
    event AssetDepositLimitUpdate(address indexed asset, uint256 depositLimit);
    event AssetStrategyUpdate(address indexed asset, address indexed strategy);
    event SetRSETH(address indexed rsETH);
    event UpdateMaxRewardAmount(uint256 maxRewardAmount);

    // methods

    function rsETH() external view returns (address);

    function assetStrategy(address asset) external view returns (address);

    function isSupportedAsset(address asset) external view returns (bool);

    function getLSTToken(bytes32 tokenId) external view returns (address);

    function getContract(bytes32 contractId) external view returns (address);

    function getSupportedAssetList() external view returns (address[] memory);

    function depositLimitByAsset(address asset) external view returns (uint256);

    function protocolFeeInBPS() external view returns (uint256);
}
