// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IStrategy } from "contracts/external/eigenlayer/interfaces/IStrategy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILRTWithdrawalManager {
    //errors
    error TokenTransferFailed();
    error EthTransferFailed();
    error InvalidAmountToWithdraw();
    error ExceedAmountToWithdraw();
    error WithdrawalLocked();
    error WithdrawalDelayNotPassed();
    error WithdrawalDelayTooSmall();
    error NoPendingWithdrawals();
    error AmountMustBeGreaterThanZero();
    error StrategyNotSupported();

    error RsETHPriceMustBeGreaterMinimum(uint256 rsEthPrice);
    error AssetPriceMustBeGreaterMinimum(uint256 assetPrice);

    struct WithdrawalRequest {
        uint256 rsETHUnstaked;
        uint256 expectedAssetAmount;
        uint256 withdrawalStartBlock;
    }

    //events
    event AssetWithdrawalQueued(
        address indexed withdrawer, address indexed asset, uint256 rsETHUnstaked, uint256 indexed userNonce
    );

    event AssetWithdrawalFinalized(
        address indexed withdrawer, address indexed asset, uint256 amountBurned, uint256 amountReceived
    );
    event EtherReceived(address indexed depositor, uint256 ethAmount, uint256 sharesAmount);

    event AssetUnlocked(
        address indexed asset, uint256 rsEthAmount, uint256 assetAmount, uint256 rsEThPrice, uint256 assetPrice
    );

    event MinAmountToWithdrawUpdated(address asset, uint256 minRsEthAmountToWithdraw);
    event WithdrawalDelayBlocksUpdated(uint256 withdrawalDelayBlocks);

    // methods

    function getExpectedAssetAmount(address asset, uint256 amount) external view returns (uint256);

    function getAvailableAssetAmount(address asset) external view returns (uint256 assetAmount);

    function getUserWithdrawalRequest(
        address asset,
        address user,
        uint256 index
    )
        external
        view
        returns (uint256 rsETHAmount, uint256 expectedAssetAmount, uint256 withdrawalStartBlock, uint256 userNonce);

    function initiateWithdrawal(address asset, uint256 withdrawAmount) external;

    function completeWithdrawal(address asset) external;

    function unlockQueue(
        address asset,
        uint256 index,
        uint256 minimumAssetPrice,
        uint256 minimumRsEthPrice
    )
        external
        returns (uint256 rsETHBurned, uint256 assetAmountUnlocked);

    // receive functions
    function receiveFromLRTUnstakingVault() external payable;
}
