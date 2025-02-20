// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTDepositPool {
    //errors
    error InvalidAmountToDeposit();
    error NotEnoughAssetToTransfer();
    error MaximumDepositLimitReached();
    error MaximumNodeDelegatorLimitReached();
    error InvalidMaximumNodeDelegatorLimit();
    error MinimumAmountToReceiveNotMet();
    error NodeDelegatorNotFound();
    error NodeDelegatorHasAssetBalance(address assetAddress, uint256 assetBalance);
    error NodeDelegatorHasETH();
    error EthTransferFailed();
    error NodeDelegatorHasUnaccountedWithdrawals();

    //events
    event MaxNodeDelegatorLimitUpdated(uint256 maxNodeDelegatorLimit);
    event NodeDelegatorAddedinQueue(address[] nodeDelegatorContracts);
    event NodeDelegatorRemovedFromQueue(address nodeDelegatorContracts);
    event AssetDeposit(
        address indexed depositor,
        address indexed asset,
        uint256 depositAmount,
        uint256 rsethMintAmount,
        string referralId
    );
    event ETHDeposit(address indexed depositor, uint256 depositAmount, uint256 rsethMintAmount, string referralId);
    event MinAmountToDepositUpdated(uint256 minAmountToDeposit);
    event MaxNegligibleAmountUpdated(uint256 maxNegligibleAmount);
    event ETHSwappedForLST(uint256 ethAmount, address indexed toAsset, uint256 returnAmount);
    event EthTransferred(address to, uint256 amount);

    // functions
    function depositETH(uint256 minRSETHAmountExpected, string calldata referralId) external payable;

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountExpected,
        string calldata referralId
    )
        external;

    function getSwapETHToAssetReturnAmount(
        address toAsset,
        uint256 ethAmountToSend
    )
        external
        view
        returns (uint256 returnAmount);

    function getTotalAssetDeposits(address asset) external view returns (uint256);

    function getAssetCurrentLimit(address asset) external view returns (uint256);

    function getRsETHAmountToMint(address asset, uint256 depositAmount) external view returns (uint256);

    function addNodeDelegatorContractToQueue(address[] calldata nodeDelegatorContract) external;

    function transferAssetToNodeDelegator(uint256 ndcIndex, address asset, uint256 amount) external;

    function updateMaxNodeDelegatorLimit(uint256 maxNodeDelegatorLimit) external;

    function getNodeDelegatorQueue() external view returns (address[] memory);

    function getAssetDistributionData(address asset)
        external
        view
        returns (
            uint256 assetLyingInDepositPool,
            uint256 assetLyingInNDCs,
            int256 assetStakedInEigenLayer,
            uint256 assetUnstakingFromEigenLayer,
            uint256 assetLyingInConverter,
            uint256 assetLyingUnstakingVault
        );

    function getETHDistributionData()
        external
        view
        returns (
            uint256 ethLyingInDepositPool,
            uint256 ethLyingInNDCs,
            int256 ethStakedInEigenLayer,
            uint256 ethUnstakingFromEigenLayer,
            uint256 ethLyingInConverter,
            uint256 ethLyingInUnstakingVault
        );

    function isNodeDelegator(address nodeDelegatorContract) external view returns (uint256);

    // receivers
    function receiveFromRewardReceiver() external payable;
    function receiveFromLRTConverter() external payable;
    function receiveFromNodeDelegator() external payable;
}
