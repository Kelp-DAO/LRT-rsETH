// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { UtilLib } from "./utils/UtilLib.sol";
import { LRTConstants } from "./utils/LRTConstants.sol";
import { ILRTConfig } from "./interfaces/ILRTConfig.sol";
import { IStrategy } from "./external/eigenlayer/interfaces/IStrategy.sol";
import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title LRTConfig - LRT Config Contract
/// @notice Handles LRT configuration
contract LRTConfig is ILRTConfig, AccessControlUpgradeable {
    mapping(bytes32 tokenKey => address tokenAddress) public tokenMap;
    mapping(bytes32 contractKey => address contractAddress) public contractMap;
    mapping(address token => bool isSupported) public isSupportedAsset;
    mapping(address token => uint256 amount) public depositLimitByAsset;
    mapping(address token => address strategy) public override assetStrategy;

    address[] public supportedAssetList;
    address public rsETH;
    uint256 public protocolFeeInBPS;

    modifier onlySupportedAsset(address asset) {
        if (!isSupportedAsset[asset]) {
            revert AssetNotSupported();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract
    /// @param admin Admin address
    /// @param stETH stETH address
    /// @param ethX ETHX address
    /// @param rsETH_ rsETH address
    function initialize(address admin, address stETH, address ethX, address rsETH_) external initializer {
        UtilLib.checkNonZeroAddress(admin);
        UtilLib.checkNonZeroAddress(rsETH_);

        __AccessControl_init();
        _setToken(LRTConstants.ST_ETH_TOKEN, stETH);
        _setToken(LRTConstants.ETHX_TOKEN, ethX);
        _addNewSupportedAsset(stETH, 100_000 ether);
        _addNewSupportedAsset(ethX, 100_000 ether);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        rsETH = rsETH_;
    }

    /// @dev Adds a new supported asset
    /// @param asset Asset address
    /// @param depositLimit Deposit limit for the asset
    function addNewSupportedAsset(address asset, uint256 depositLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _addNewSupportedAsset(asset, depositLimit);
    }

    /// @dev private function to add a new supported asset
    /// @param asset Asset address
    /// @param depositLimit Deposit limit for the asset
    function _addNewSupportedAsset(address asset, uint256 depositLimit) private {
        UtilLib.checkNonZeroAddress(asset);
        if (isSupportedAsset[asset]) {
            revert AssetAlreadySupported();
        }
        isSupportedAsset[asset] = true;
        supportedAssetList.push(asset);
        depositLimitByAsset[asset] = depositLimit;
        emit AddedNewSupportedAsset(asset, depositLimit);
    }

    /// @dev Updates the deposit limit for an asset
    /// @param asset Asset address
    /// @param depositLimit New deposit limit
    function updateAssetDepositLimit(
        address asset,
        uint256 depositLimit
    )
        external
        onlyRole(LRTConstants.MANAGER)
        onlySupportedAsset(asset)
    {
        depositLimitByAsset[asset] = depositLimit;
        emit AssetDepositLimitUpdate(asset, depositLimit);
    }

    /// @dev Updates the strategy for an asset
    /// @param asset Asset address
    /// @param strategy New strategy address
    function updateAssetStrategy(
        address asset,
        address strategy
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlySupportedAsset(asset)
    {
        UtilLib.checkNonZeroAddress(strategy);
        if (assetStrategy[asset] == strategy) {
            revert ValueAlreadyInUse();
        }
        // if strategy is already set, check if it has any funds
        if (assetStrategy[asset] != address(0)) {
            // get ndcs
            address depositPool = getContract(LRTConstants.LRT_DEPOSIT_POOL);
            address[] memory ndcs = ILRTDepositPool(depositPool).getNodeDelegatorQueue();

            uint256 length = ndcs.length;
            for (uint256 i = 0; i < length;) {
                uint256 ndcBalance = IStrategy(assetStrategy[asset]).userUnderlyingView(ndcs[i]);
                if (ndcBalance > 0) {
                    revert CannotUpdateStrategyAsItHasFundsNDCFunds(ndcs[i], ndcBalance);
                }

                unchecked {
                    ++i;
                }
            }
        }

        assetStrategy[asset] = strategy;
        emit AssetStrategyUpdate(asset, strategy);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/
    function getLSTToken(bytes32 tokenKey) external view override returns (address) {
        UtilLib.checkNonZeroAddress(tokenMap[tokenKey]);
        return tokenMap[tokenKey];
    }

    function getContract(bytes32 contractKey) public view override returns (address) {
        UtilLib.checkNonZeroAddress(contractMap[contractKey]);
        return contractMap[contractKey];
    }

    function getSupportedAssetList() external view override returns (address[] memory) {
        return supportedAssetList;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Set the protocol fee bps
    /// @param _protocolFeeInBPS protocol fee bps
    function setProtocolFeeBps(uint256 _protocolFeeInBPS) external onlyRole(LRTConstants.DEFAULT_ADMIN_ROLE) {
        protocolFeeInBPS = _protocolFeeInBPS;
    }

    /// @dev Sets the rsETH contract address. Only callable by the admin
    /// @param rsETH_ rsETH contract address
    function setRSETH(address rsETH_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(rsETH_);
        rsETH = rsETH_;
        emit SetRSETH(rsETH_);
    }

    function setToken(bytes32 tokenKey, address assetAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setToken(tokenKey, assetAddress);
    }

    /// @dev private function to set a token
    /// @param key Token key
    /// @param val Token address
    function _setToken(bytes32 key, address val) private {
        UtilLib.checkNonZeroAddress(val);
        if (tokenMap[key] == val) {
            revert ValueAlreadyInUse();
        }
        tokenMap[key] = val;
        emit SetToken(key, val);
    }

    function setContract(bytes32 contractKey, address contractAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setContract(contractKey, contractAddress);
    }

    /// @dev private function to set a contract
    /// @param key Contract key
    /// @param val Contract address
    function _setContract(bytes32 key, address val) private {
        UtilLib.checkNonZeroAddress(val);
        if (contractMap[key] == val) {
            revert ValueAlreadyInUse();
        }
        contractMap[key] = val;
        emit SetContract(key, val);
    }
}
