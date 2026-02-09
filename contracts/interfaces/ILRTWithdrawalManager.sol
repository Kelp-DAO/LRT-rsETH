// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILRTWithdrawalManager {
    //errors
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
    error CantInstantWithdrawMoreThanAvailable();
    error NotEnoughRsETH();
    error InstantWithdrawalNotEnabled();
    error FeeTooHigh();
    error PendingWithdrawalsExist();
    error TreasuryTransferFailed();
    error NoWithdrawalRequests(address user, address asset);
    error AaveIntegrationNotEnabled();
    error InsufficientAaveBalance();
    error InvalidAaveConfiguration();
    error AaveHealthCheckFailed();
    error InsufficientLiquidityForWithdrawal();
    error UnauthorizedCaller();
    error AaveIntegrationAlreadyInDesiredState(bool enabled);

    struct UnlockParams {
        uint256 rsETHPrice;
        uint256 assetPrice;
        uint256 totalAvailableAssets;
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
    event InstantWithdrawalEnabledUpdated(address indexed asset, bool enabled);
    event InstantWithdrawalFeeUpdated(uint256 feeBasisPoints);
    event InstantWithdrawalFeeRecipientUpdated(address indexed feeRecipient);
    event InstantWithdrawalFeeCollected(address indexed user, address indexed asset, uint256 fee);
    event TreasuryWithdrawalSettled(address indexed asset, uint256 amount);
    event RemainingAssetsSwept(address indexed asset, uint256 amount, address indexed treasury);
    event AssetWithdrawalCompletedBy(address indexed user);
    event AaveIntegrationConfigured(
        address indexed aavePool, address indexed aaveWETHGateway, address indexed aaveAWETH, address aaveDataProvider
    );
    event AaveIntegrationEnabled(bool enabled);
    event ETHDepositedToAave(uint256 amount, uint256 totalDeposited);
    event ETHWithdrawnFromAave(uint256 amount, uint256 totalDeposited);
    event InterestCollectedToTreasury(uint256 interestAmount, address indexed treasury);
    event EmergencyWithdrawFromAave(uint256 amount, address indexed recipient);
    event AaveDepositFailed(uint256 amount, bytes reason);

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

    function completeWithdrawalForUser(address asset, address user, string calldata referralId) external;

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

    function setInstantWithdrawalEnabled(address asset, bool enabled) external;

    function setInstantWithdrawalFee(uint256 feeBasisPoints) external;

    function setInstantWithdrawalFeeRecipient(address feeRecipient) external;

    function assetsCommitted(address asset) external view returns (uint256);

    // Treasury withdrawal flow functions
    function hasUnlockedWithdrawals(address asset) external view returns (bool);

    function sweepRemainingAssets(address asset) external returns (uint256 transferredAmount);

    // Aave integration functions
    function configureAaveIntegration(
        address aavePool_,
        address aaveWETHGateway_,
        address aaveAWETH_,
        address aaveDataProvider_
    )
        external;

    function setAaveIntegrationEnabled(bool enabled) external;

    function depositIdleETHToAave(uint256 amount) external;

    function collectInterestToTreasury() external returns (uint256 interestAmount);

    function emergencyWithdrawFromAave(uint256 amount) external;

    function getAaveBalance() external view returns (uint256);

    function getAccruedInterest() external view returns (uint256);

    function aaveHealthCheck() external view returns (bool);
}
