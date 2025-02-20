// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTUnstakingVault {
    error CallerNotLRTNodeDelegator();
    error EthTransferFailed();
    error CallerNotLRTWithdrawalManager();
    error WithdrawalAlreadyRegistered();
    error IncorrectStaker();
    error WithdrawalNotPending();

    event EthReceived(address sender, uint256 amount);
    event EthTransferred(address nodeDelegator, uint256 amount);

    // functions
    function sharesUnstaking(address asset) external view returns (uint256);

    function getAssetsUnstaking(address asset) external view returns (uint256);

    function getStakedAssetBalances(address user) external view returns (address[] memory, uint256[] memory);

    function balanceOf(address asset) external view returns (uint256);

    function addSharesUnstaking(address asset, uint256 amount) external;

    function reduceSharesUnstaking(address asset, uint256 amount) external;

    function trackWithdrawal(bytes32 withdrawalRoot) external;

    function redeem(address asset, uint256 amount) external;

    // receive functions
    function receiveFromLRTDepositPool() external payable;
    function receiveFromNodeDelegator() external payable;
}
