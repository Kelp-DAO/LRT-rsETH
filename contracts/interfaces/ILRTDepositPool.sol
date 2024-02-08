// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface ILRTDepositPool {
    //errors
    error TokenTransferFailed();
    error InvalidAmountToDeposit();
    error NotEnoughAssetToTransfer();
    error MaximumDepositLimitReached();
    error MaximumNodeDelegatorLimitReached();
    error InvalidMaximumNodeDelegatorLimit();
    error MinimumAmountToReceiveNotMet();
    error NodeDelegatorNotFound();
    error NodeDelegatorHasAssetBalance(address assetAddress, uint256 assetBalance);

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
    event AssetSwapped(
        address indexed fromAsset, address indexed toAsset, uint256 fromAssetAmount, uint256 toAssetAmount
    );

    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountExpected,
        string calldata referralId
    )
        external;

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
        returns (uint256 assetLyingInDepositPool, uint256 assetLyingInNDCs, uint256 assetStakedInEigenLayer);

    function getETHDistributionData()
        external
        view
        returns (uint256 ethLyingInDepositPool, uint256 ethLyingInNDCs, uint256 ethStakedInEigenLayer);
}
