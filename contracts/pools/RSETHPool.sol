// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {
    ERC20Upgradeable, IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "../utils/UtilLib.sol";

interface IOracle {
    function getRate() external view returns (uint256);
}

/// @title RSETHPool
/// @notice This contract is the pool contract for the rsETH pool on *Arbitrum*
/// @dev it differs from other RSETHPool contracts in other chains as it uses LZ_RSETH as the canonical rsETH token of
/// the chain.
/// @dev it was the first RSETHPool contract to be deployed in an L2 hence the  legacy variables
contract RSETHPool is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:oz-renamed-from rsETH
    IERC20Upgradeable public wrsETH;
    /// @custom:oz-renamed-from wstETH
    IERC20Upgradeable public legacyWstETH; // legacy variable

    uint256 public feeBps; // Basis points for fees
    uint256 public feeEarnedInETH;
    /// @custom:oz-renamed-from feeEarnedInWstETH
    uint256 public legacyFeeEarnedInWstETH; // legacy variable

    address public rsETHOracle;
    /// @custom:oz-renamed-from wstETH_ETHOracle
    address public legacyWstETH_ETHOracle; // legacy variable
    /// @custom:oz-renamed-from MANAGER_ROLE
    bytes32 public constant LEGACY_MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // new variables
    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");
    bool public isEthDepositEnabled;
    mapping(address token => uint256 feeEarned) public feeEarnedInToken;
    mapping(address token => address oracle) public supportedTokenOracle;
    address[] public supportedTokenList;

    error InvalidAmount();
    error TransferFailed();
    error UnsupportedOracle();
    error UnsupportedToken();
    error AlreadySupportedToken();
    error TokenNotFoundError();
    error EthDepositDisabled();

    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event FeesWithdrawn(uint256 feeEarnedInETH, address token);
    event AssetsMovedForBridging(uint256 ethBalanceMinusFees);
    event AssetsMovedForBridging(uint256 tokenBalanceMinusFees, address token);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);
    event AddSupportedToken(address token);
    event RemovedSupportedToken(address token);
    event IsEthDepositEnabled(bool isEthDepositEnabled);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract
    /// @param admin The admin address
    /// @param manager The manager address
    /// @param _rsETH The canonical rsETH token address, LZ_RSETH on Arbitrum
    /// @param _wstETH The wstETH token address
    /// @param _feeBps The fee basis points
    /// @param _rsETHOracle The rsETHOracle address
    /// @param _wstETH_ETHOracle oracle address for wstETH/ETH
    function initialize(
        address admin,
        address manager,
        address _rsETH,
        address _wstETH,
        uint256 _feeBps,
        address _rsETHOracle,
        address _wstETH_ETHOracle
    )
        public
        initializer
    {
        UtilLib.checkNonZeroAddress(_rsETH);
        UtilLib.checkNonZeroAddress(_wstETH);

        __ERC20_init("rsETH", "rsETH");
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        // legacy settings
        _setupRole(LEGACY_MANAGER_ROLE, admin);
        _setupRole(LEGACY_MANAGER_ROLE, manager);

        wrsETH = IERC20Upgradeable(_rsETH);
        legacyWstETH = IERC20Upgradeable(_wstETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
        legacyWstETH_ETHOracle = _wstETH_ETHOracle;
    }

    modifier onlySupportedToken(address token) {
        if (supportedTokenOracle[token] == address(0)) revert UnsupportedToken();
        _;
    }

    /// @dev Gets the rate from the rsETHOracle
    function getRate() public view returns (uint256) {
        return IOracle(rsETHOracle).getRate();
    }

    /// @dev Returns the list of supported tokens
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokenList;
    }

    /// @dev Swaps ETH for rsETH
    /// @param referralId The referral id
    function deposit(string memory referralId) external payable nonReentrant {
        if (!isEthDepositEnabled) revert EthDepositDisabled();
        uint256 amount = msg.value;

        if (amount == 0) revert InvalidAmount();

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount);

        feeEarnedInETH += fee;

        wrsETH.transfer(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId);
    }

    /// @dev Swaps token for rsETH
    /// @param token The token address
    /// @param amount The amount of token
    /// @param referralId The referral id
    function deposit(
        address token,
        uint256 amount,
        string memory referralId
    )
        external
        nonReentrant
        onlySupportedToken(token)
    {
        if (amount == 0) revert InvalidAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount, token);

        feeEarnedInToken[token] += fee;

        wrsETH.transfer(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId); // Add token address?
    }

    /// @dev view function to get the rsETH amount for a given amount of ETH
    /// @param amount The amount of ETH
    /// @return rsETHAmount The amount of rsETH that will be received
    /// @return fee The fee that will be charged
    function viewSwapRsETHAmountAndFee(uint256 amount) public view returns (uint256 rsETHAmount, uint256 fee) {
        fee = amount * feeBps / 10_000;
        uint256 amountAfterFee = amount - fee;

        // rate of rsETH in ETH
        uint256 rsETHToETHrate = getRate();

        // Calculate the final rsETH amount
        rsETHAmount = amountAfterFee * 1e18 / rsETHToETHrate;
    }

    /// @dev view function to get the rsETH amount for a given amount of token
    /// @param amount The amount of token
    /// @return rsETHAmount The amount of rsETH that will be received
    /// @return fee The fee that will be charged
    function viewSwapRsETHAmountAndFee(
        uint256 amount,
        address token
    )
        public
        view
        onlySupportedToken(token)
        returns (uint256 rsETHAmount, uint256 fee)
    {
        fee = amount * feeBps / 10_000;
        uint256 amountAfterFee = amount - fee;

        // rate of rsETH in ETH
        uint256 rsETHToETHrate = getRate();

        // rate of token in ETH
        uint256 tokenToETHRate = IOracle(supportedTokenOracle[token]).getRate();

        // Calculate the final rsETH amount
        rsETHAmount = amountAfterFee * tokenToETHRate / rsETHToETHrate;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(address receiver) external onlyRole(BRIDGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInETH = feeEarnedInETH;
        feeEarnedInETH = 0;
        (bool success,) = payable(receiver).call{ value: amountToSendInETH }("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(amountToSendInETH);
    }

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(address receiver, address token) external onlySupportedToken(token) onlyRole(BRIDGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInToken = feeEarnedInToken[token];
        feeEarnedInToken[token] = 0;
        IERC20(token).safeTransfer(receiver, amountToSendInToken);

        emit FeesWithdrawn(amountToSendInToken, token);
    }

    /// @dev Withdraws assets from the contract for bridging
    function moveAssetsForBridging() external onlyRole(BRIDGER_ROLE) {
        // withdraw ETH - fees
        uint256 ethBalanceMinusFees = address(this).balance - feeEarnedInETH;

        (bool success,) = msg.sender.call{ value: ethBalanceMinusFees }("");
        if (!success) revert TransferFailed();

        emit AssetsMovedForBridging(ethBalanceMinusFees);
    }

    /// @dev Withdraws assets from the contract for bridging
    function moveAssetsForBridging(address token) external onlySupportedToken(token) onlyRole(BRIDGER_ROLE) {
        // withdraw token - fees
        uint256 tokenBalanceMinusFees = IERC20(token).balanceOf(address(this)) - feeEarnedInToken[token];

        IERC20(token).safeTransfer(msg.sender, tokenBalanceMinusFees);

        emit AssetsMovedForBridging(tokenBalanceMinusFees, token);
    }

    /// @dev Sets the fee basis points
    /// @param _feeBps The fee basis points
    function setFeeBps(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeBps > 10_000) revert InvalidAmount();

        feeBps = _feeBps;

        emit FeeBpsSet(_feeBps);
    }

    /// @dev Sets the isEthDepositEnabled flag
    /// @param _isEthDepositEnabled The isEthDepositEnabled flag
    function setIsEthDepositEnabled(bool _isEthDepositEnabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isEthDepositEnabled = _isEthDepositEnabled;
        emit IsEthDepositEnabled(_isEthDepositEnabled);
    }

    /// @dev Sets the rsETHOracle address
    /// @param _rsETHOracle The rsETHOracle address
    function setRSETHOracle(address _rsETHOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        rsETHOracle = _rsETHOracle;

        emit OracleSet(_rsETHOracle);
    }

    /// @dev Adds a supported token
    /// @param token The token address
    function addSupportedToken(address token, address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        UtilLib.checkNonZeroAddress(oracle);

        if (supportedTokenOracle[token] != address(0)) {
            revert AlreadySupportedToken();
        }
        if (IOracle(rsETHOracle).getRate() == 0) {
            revert UnsupportedOracle();
        }
        supportedTokenList.push(token);
        supportedTokenOracle[token] = oracle;

        emit AddSupportedToken(token);
    }

    /// @dev Removes a supported token
    /// @param token The token address
    function removeSupportedToken(address token, uint256 tokenIndex) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        if (supportedTokenList[tokenIndex] != token) {
            revert TokenNotFoundError();
        }
        delete supportedTokenOracle[token];
        supportedTokenList[tokenIndex] = supportedTokenList[supportedTokenList.length - 1];
        supportedTokenList.pop();
        emit RemovedSupportedToken(token);
    }
}
