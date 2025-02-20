// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTWithdrawalManager {
    //errors
    error TokenTransferFailed();
    error EthTransferFailed();
    error InvalidAmountToWithdraw();
    error ExceedAmountToWithdraw();
    error WithdrawalLocked();
    error WithdrawalDelayNotPassed();
    error ExceedWithdrawalDelay();
    error NoPendingWithdrawals();
    error AmountMustBeGreaterThanZero();
    error StrategyNotSupported();

    error RsETHPriceOutOfPriceRange(uint256 rsEthPrice);
    error AssetPriceOutOfPriceRange(uint256 assetPrice);

    struct UnlockParams {
        uint256 rsETHPrice;
        uint256 assetPrice;
        uint256 totalAvailableAssets;
        uint256 firstExcludedIndex;
    }

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

    event ReferralIdEmitted(string referralId);

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

    function initiateWithdrawal(address asset, uint256 withdrawAmount, string calldata referralId) external;

    function completeWithdrawal(address asset, string calldata referralId) external;

    function unlockQueue(
        address asset,
        uint256 index,
        uint256 minimumAssetPrice,
        uint256 minimumRsEthPrice,
        uint256 maximumAssetPrice,
        uint256 maximumRsEthPrice
    )
        external
        returns (uint256 rsETHBurned, uint256 assetAmountUnlocked);

    // receive functions
    function receiveFromLRTUnstakingVault() external payable;
}
