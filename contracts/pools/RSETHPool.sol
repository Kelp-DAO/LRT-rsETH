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

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract RSETHPool is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    IERC20Upgradeable public rsETH;
    IERC20Upgradeable public wstETH;
    uint256 public feeBps; // Basis points for fees
    uint256 public feeEarnedInETH;
    uint256 public feeEarnedInWstETH;
    address public rsETHOracle;
    address public wstETH_ETHOracle;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    error InvalidAmount();
    error TransferFailed();

    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event FeesWithdrawn(uint256 feeEarnedInETH, uint256 feeEarnedInWstETH);
    event CollectedAssetsWithdrawn(uint256 wwstETHBalanceMinusFees, uint256 ethBalanceMinusFees);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize the contract
    /// @param admin The admin address
    /// @param manager The manager address
    /// @param _rsETH The rsETH token address
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
        _setupRole(MANAGER_ROLE, admin);
        _setupRole(MANAGER_ROLE, manager);

        rsETH = IERC20Upgradeable(_rsETH);
        wstETH = IERC20Upgradeable(_wstETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
        wstETH_ETHOracle = _wstETH_ETHOracle;
    }

    /// @dev Gets the rate from the rsETHOracle
    function getRate() public view returns (uint256) {
        return IOracle(rsETHOracle).getRate();
    }

    /// @dev Swaps ETH or wstETH for rsETH
    /// @param wstETHAmount The amount of wstETH to swap for rsETH. Use 0 if swapping ETH for rsETH
    function swapToRsETH(uint256 wstETHAmount, string calldata referralId) external payable nonReentrant {
        bool isWstETH;
        uint256 amount;

        if (wstETHAmount > 0) {
            if (msg.value > 0) revert InvalidAmount(); // cannot send both wstETH and ETH
            isWstETH = true;
            amount = wstETHAmount;
            wstETH.transferFrom(msg.sender, address(this), wstETHAmount);
        } else {
            if (msg.value == 0) revert InvalidAmount();
            amount = msg.value;
        }

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount, isWstETH);

        if (isWstETH) {
            feeEarnedInWstETH += fee;
        } else {
            feeEarnedInETH += fee;
        }

        rsETH.transfer(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId);
    }

    /// @dev view function to get the rsETH amount for a given amount of wstETH or ETH
    /// @param amount The amount of wstETH or ETH
    /// @param isWstETH True if the amount is in wstETH, false if it is in ETH
    /// @return rsETHAmount The amount of rsETH that will be received
    /// @return fee The fee that will be charged
    function viewSwapRsETHAmountAndFee(
        uint256 amount,
        bool isWstETH
    )
        public
        view
        returns (uint256 rsETHAmount, uint256 fee)
    {
        fee = amount * feeBps / 10_000;
        uint256 amountAfterFee = amount - fee;

        if (isWstETH) {
            // Adjust for wstETH to ETH conversion using the oracle
            (, int256 ETHPrice,,,) = AggregatorV3Interface(wstETH_ETHOracle).latestRoundData();

            uint256 normalizedPriceForDecimalsUnit =
                uint256(ETHPrice) * 1e18 / 10 ** uint256(AggregatorV3Interface(wstETH_ETHOracle).decimals());

            amountAfterFee = amountAfterFee * normalizedPriceForDecimalsUnit / 1e18;
        }

        // rate of rsETH in ETH
        uint256 rsETHToETHrate = getRate();

        // Calculate the final rsETH amount
        rsETHAmount = amountAfterFee * 1e18 / rsETHToETHrate;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(address receiver) external onlyRole(MANAGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInETH = feeEarnedInETH;
        feeEarnedInETH = 0;
        (bool success,) = payable(receiver).call{ value: amountToSendInETH }("");
        if (!success) revert TransferFailed();

        // withdraw fees in wstETH
        uint256 amountToSendInWSETH = feeEarnedInWstETH;
        feeEarnedInWstETH = 0;
        wstETH.transfer(receiver, amountToSendInWSETH);

        emit FeesWithdrawn(amountToSendInETH, amountToSendInWSETH);
    }

    /// @dev Withdraws collected assets by the pool
    function withdrawCollectedAssets(address receiver) external onlyRole(MANAGER_ROLE) {
        // withdraw wstETH - fees
        uint256 wstETHBalanceMinusFees = wstETH.balanceOf(address(this)) - feeEarnedInWstETH;

        wstETH.transfer(receiver, wstETHBalanceMinusFees);

        // withdraw ETH - fees
        uint256 ethBalanceMinusFees = address(this).balance - feeEarnedInETH;

        (bool success,) = payable(receiver).call{ value: ethBalanceMinusFees }("");
        if (!success) revert TransferFailed();

        emit CollectedAssetsWithdrawn(wstETHBalanceMinusFees, ethBalanceMinusFees);
    }

    /// @dev withdraw rsETH from the pool
    /// @dev This function is only callable by the manager
    /// @param receiver The address to receive the rsETH
    /// @param amount The amount of rsETH to withdraw
    function withdrawRsETH(address receiver, uint256 amount) external onlyRole(MANAGER_ROLE) {
        rsETH.transfer(receiver, amount);
    }

    /// @dev Sets the fee basis points
    /// @param _feeBps The fee basis points
    function setFeeBps(uint256 _feeBps) external onlyRole(MANAGER_ROLE) {
        if (_feeBps > 10_000) revert InvalidAmount();

        feeBps = _feeBps;

        emit FeeBpsSet(_feeBps);
    }

    /// @dev Sets the rsETHOracle address
    /// @param _rsETHOracle The rsETHOracle address
    function setRSETHOracle(address _rsETHOracle) external onlyRole(MANAGER_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        rsETHOracle = _rsETHOracle;

        emit OracleSet(_rsETHOracle);
    }

    /// @dev Sets the wstETH_ETHOracle address
    /// @param _wstETH_ETHOracle The wstETH_ETHOracle address
    function setWstETH_ETHOracle(address _wstETH_ETHOracle) external onlyRole(MANAGER_ROLE) {
        UtilLib.checkNonZeroAddress(_wstETH_ETHOracle);

        wstETH_ETHOracle = _wstETH_ETHOracle;

        emit OracleSet(_wstETH_ETHOracle);
    }
}
