// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILRTConverter {
    error UserNotWhitelisted();
    error InvalidAmount();
    error UnstakeLimitExceeded();
    error WhitelistedAllowanceExceeded();
    error NotEnoughAssetToTransfer();

    event ConvertedEigenlayerAssetToRsEth(address indexed receiver, uint256 rsethAmount, bytes32 withdrawalRoot);
    event ETHSwappedForLST(uint256 ethAmount, address indexed toAsset, uint256 returnAmount);
    event EthTransferred(address to, uint256 amount);

    // stETH unstaking limit events
    event UserWhitelisted(address indexed user, bool whitelisted);
    event WithdrawalIntentDeclared(address indexed user, uint256 amount);

    function ethValueInWithdrawal() external view returns (uint256);

    function transferAssetFromDepositPool(address _asset, uint256 _amount) external;

    function setUserWhitelisted(address user, bool whitelisted) external;
    function batchSetUserWhitelisted(address[] calldata users, bool whitelisted) external;
    function declareWithdrawalIntent(uint256 amount) external;

    // View functions
    function getUnstakeLimits() external view returns (uint256 whitelistedAllowance, uint256 activeETHWithdrawals);
    function isUserWhitelisted(address user) external view returns (bool);
    function whitelistedUnstakeAllowance() external view returns (uint256);
}
