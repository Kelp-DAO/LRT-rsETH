// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTConverter {
    error NotEnoughAssetToTransfer();
    error TokenTransferFailed();
    error InvalidWithdrawer();
    error WithdrawalRootNotPending();
    error WithdrawalRootAlreadyProcess();
    error ConversionLimitReached();
    error WithdrawalRootNotProcessed();
    error MinimumExpectedReturnNotReached();

    event ConvertedEigenlayerAssetToRsEth(address indexed reciever, uint256 rsethAmount, bytes32 withdrawalRoot);
    event ETHSwappedForLST(uint256 ethAmount, address indexed toAsset, uint256 returnAmount);
    event EthTransferred(address to, uint256 amount);

    function ethValueInWithdrawal() external view returns (uint256);

    function transferAssetFromDepositPool(address _asset, uint256 _amount) external;
}
