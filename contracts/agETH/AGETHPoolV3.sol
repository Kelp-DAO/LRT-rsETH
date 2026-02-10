// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";

interface IOracle {
    function getRate() external view returns (uint256);
}

interface IERC20AgETH is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;
}

contract AGETHPoolV3 is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IERC20AgETH public agETH;
    uint256 public feeBps; // Basis points for fees
    uint256 public feeEarnedInETH;
    address public agETHOracle;

    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");

    bool public isEthDepositEnabled;
    mapping(address token => uint256 feeEarned) public feeEarnedInToken;
    mapping(address token => address oracle) public supportedTokenOracle;
    address[] public supportedTokenList;

    error InvalidAmount();
    error InvalidFeeAmount();
    error TransferFailed();
    error UnsupportedToken();
    error UnsupportedOracle();
    error AlreadySupportedToken();
    error TokenNotFoundError();
    error TokenBalanceNotZero();
    error EthDepositDisabled();

    event SwapOccurred(address indexed user, uint256 agETHAmount, uint256 fee, string referralId);
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event FeesWithdrawn(uint256 feeEarnedInETH, address token);
    event AssetsMovedForBridging(uint256 ethBalanceMinusFees);
    event AssetsMovedForBridging(uint256 tokenBalanceMinusFees, address token);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);
    event AddSupportedToken(address token);
    event RemovedSupportedToken(address token);
    event IsEthDepositEnabled(bool isEthDepositEnabled);

    modifier onlySupportedToken(address token) {
        if (supportedTokenOracle[token] == address(0)) revert UnsupportedToken();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract
    /// @param admin The admin address
    /// @param bridger The bridger address
    /// @param _agETH The agETH token address
    /// @param _feeBps The fee basis points
    /// @param _agETHOracle The agETHOracle address
    function initialize(
        address admin,
        address bridger,
        address _agETH,
        uint256 _feeBps,
        address _agETHOracle
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(_agETH);
        UtilLib.checkNonZeroAddress(_agETHOracle);

        __ERC20_init("agETH", "agETH");
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(BRIDGER_ROLE, admin);
        _setupRole(BRIDGER_ROLE, bridger);

        agETH = IERC20AgETH(_agETH);
        feeBps = _feeBps;
        agETHOracle = _agETHOracle;
        isEthDepositEnabled = true;
    }

    /// @dev Gets the rate from the agETHOracle
    function getRate() public view returns (uint256) {
        return IOracle(agETHOracle).getRate();
    }

    /// @dev Returns the list of supported tokens
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokenList;
    }

    /// @dev Swaps ETH for agETH
    /// @param referralId The referral id
    function deposit(string memory referralId) external payable nonReentrant {
        if (!isEthDepositEnabled) revert EthDepositDisabled();
        uint256 amount = msg.value;

        if (amount == 0) revert InvalidAmount();

        (uint256 agETHAmount, uint256 fee) = viewSwapAgETHAmountAndFee(amount);

        feeEarnedInETH += fee;

        agETH.mint(msg.sender, agETHAmount);

        emit SwapOccurred(msg.sender, agETHAmount, fee, referralId);
    }

    /// @dev Swaps token for agETH
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

        (uint256 agETHAmount, uint256 fee) = viewSwapAgETHAmountAndFee(amount, token);

        feeEarnedInToken[token] += fee;

        agETH.mint(msg.sender, agETHAmount);

        emit SwapOccurred(msg.sender, agETHAmount, fee, referralId);
    }

    /// @dev View function to get the agETH amount for a given amount of ETH
    /// @param amount The amount of ETH
    /// @return agETHAmount The amount of agETH that will be received
    /// @return fee The fee that will be charged
    function viewSwapAgETHAmountAndFee(uint256 amount) public view returns (uint256 agETHAmount, uint256 fee) {
        fee = amount * feeBps / 10_000;
        uint256 amountAfterFee = amount - fee;

        // rate of agETH in ETH
        uint256 agETHToETHrate = getRate();

        // Calculate the final agETH amount
        agETHAmount = amountAfterFee * 1e18 / agETHToETHrate;
    }

    /// @dev View function to get the agETH amount for a given amount of token
    /// @param amount The amount of token
    /// @return agETHAmount The amount of agETH that will be received
    /// @return fee The fee that will be charged
    function viewSwapAgETHAmountAndFee(
        uint256 amount,
        address token
    )
        public
        view
        onlySupportedToken(token)
        returns (uint256 agETHAmount, uint256 fee)
    {
        fee = amount * feeBps / 10_000;
        uint256 amountAfterFee = amount - fee;

        // rate of agETH in ETH
        uint256 agETHToETHrate = getRate();

        // rate of token in ETH
        uint256 tokenToETHRate = IOracle(supportedTokenOracle[token]).getRate();

        // Calculate the final agETH amount
        agETHAmount = amountAfterFee * tokenToETHRate / agETHToETHrate;
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
        if (_feeBps > 10_000) revert InvalidFeeAmount();

        feeBps = _feeBps;

        emit FeeBpsSet(_feeBps);
    }

    /// @dev Sets the isEthDepositEnabled flag
    /// @param _isEthDepositEnabled The isEthDepositEnabled flag
    function setIsEthDepositEnabled(bool _isEthDepositEnabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isEthDepositEnabled = _isEthDepositEnabled;
        emit IsEthDepositEnabled(_isEthDepositEnabled);
    }

    /// @dev Sets the agETHOracle address
    /// @param _agETHOracle The agETHOracle address
    function setAgETHOracle(address _agETHOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_agETHOracle);

        agETHOracle = _agETHOracle;

        emit OracleSet(_agETHOracle);
    }

    /// @dev Adds a supported token
    /// @param token The token address
    function addSupportedToken(address token, address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        UtilLib.checkNonZeroAddress(oracle);

        if (supportedTokenOracle[token] != address(0)) {
            revert AlreadySupportedToken();
        }
        if (IOracle(oracle).getRate() == 0) {
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
        if (supportedTokenList[tokenIndex] != token) revert TokenNotFoundError();
        if (IERC20(token).balanceOf(address(this)) != 0) revert TokenBalanceNotZero();

        delete supportedTokenOracle[token];
        supportedTokenList[tokenIndex] = supportedTokenList[supportedTokenList.length - 1];
        supportedTokenList.pop();
        emit RemovedSupportedToken(token);
    }
}
