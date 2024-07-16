// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {
    ERC20Upgradeable, IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { UtilLib } from "../utils/UtilLib.sol";

interface IOracle {
    function getRate() external view returns (uint256);
}

interface IERC20WstETH is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;
}

contract RSETHPoolV2 is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    IERC20WstETH public wrsETH;
    uint256 public feeBps; // Basis points for fees
    uint256 public feeEarnedInETH;
    address public rsETHOracle;

    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");

    error InvalidAmount();
    error TransferFailed();

    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event AssetsMovedForBridging(uint256 ethBalanceMinusFees);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract
    /// @param admin The admin address
    /// @param bridger The bridger address
    /// @param _wrsETH The rsETH token address
    /// @param _feeBps The fee basis points
    /// @param _rsETHOracle The rsETHOracle address
    function initialize(
        address admin,
        address bridger,
        address _wrsETH,
        uint256 _feeBps,
        address _rsETHOracle
    )
        public
        initializer
    {
        UtilLib.checkNonZeroAddress(_wrsETH);
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        __ERC20_init("rsETH", "rsETH");
        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(BRIDGER_ROLE, admin);
        _setupRole(BRIDGER_ROLE, bridger);

        wrsETH = IERC20WstETH(_wrsETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
    }

    /// @dev Gets the rate from the rsETHOracle
    function getRate() public view returns (uint256) {
        return IOracle(rsETHOracle).getRate();
    }

    /// @dev Swaps ETH for rsETH
    /// @param referralId The referral id
    function deposit(string memory referralId) external payable nonReentrant {
        uint256 amount = msg.value;

        if (amount == 0) revert InvalidAmount();

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount);

        feeEarnedInETH += fee;

        wrsETH.mint(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId);
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

    /// @dev Withdraws assets from the contract for bridging
    function moveAssetsForBridging() external onlyRole(BRIDGER_ROLE) {
        // withdraw ETH - fees
        uint256 ethBalanceMinusFees = address(this).balance - feeEarnedInETH;

        (bool success,) = msg.sender.call{ value: ethBalanceMinusFees }("");
        if (!success) revert TransferFailed();

        emit AssetsMovedForBridging(ethBalanceMinusFees);
    }

    /// @dev Sets the fee basis points
    /// @param _feeBps The fee basis points
    function setFeeBps(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeBps > 10_000) revert InvalidAmount();

        feeBps = _feeBps;

        emit FeeBpsSet(_feeBps);
    }

    /// @dev Sets the rsETHOracle address
    /// @param _rsETHOracle The rsETHOracle address
    function setRSETHOracle(address _rsETHOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        rsETHOracle = _rsETHOracle;

        emit OracleSet(_rsETHOracle);
    }
}
