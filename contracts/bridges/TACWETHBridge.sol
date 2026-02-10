// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";
import { IOFT, SendParam, MessagingFee, OFTReceipt } from "contracts/external/layerzero/interfaces/IOFT.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";

/**
 * @title TACWETHBridge
 * @notice This contract is the wrapper for the WETH OFT bridge from TAC to ETH mainnet
 */
contract TACWETHBridge is IL2TokenBridge, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The divisor for basis points calculations
    uint256 public constant BASIS_POINTS_DIVISOR = 10_000;

    /// @notice The WETH OFT contract on TAC
    IOFT public immutable wethOFT;

    /// @notice The LayerZero ID for the ETH mainnet
    uint32 public immutable dstLzChainId;

    /// @notice The maximum slippage tolerance for the bridge
    uint256 public slippageTolerance;

    /// @notice Custom errors
    error InvalidLzChainId();
    error ZeroAmount();
    error InvalidNativeFee();
    error InvalidSlippageTolerance();
    error InvalidMinAmount();

    /**
     * @notice Event emitted when WETH is bridged to L1
     * @param lzChainId The LayerZero chain ID of the destination chain
     * @param l1Receiver The address of the recipient on L1
     * @param amountSent The amount of WETH sent from TAC
     * @param amountReceived The amount of WETH received on L1
     */
    event BridgedWETHToL1(
        uint32 indexed lzChainId, address indexed l1Receiver, uint256 amountSent, uint256 amountReceived
    );

    /**
     * @notice Event emitted when the slippage tolerance is updated
     * @param newSlippageTolerance The new slippage tolerance in basis points
     */
    event SlippageToleranceUpdated(uint256 newSlippageTolerance);

    /**
     * @notice Constructor for the TACWETHBridge contract
     * @param _admin Address of the admin
     * @param _wethOFT Address of the WETH OFT contract on TAC
     * @param _dstLzChainId LayerZero ID for the ETH mainnet
     * @param _slippageTolerance The slippage tolerance for the bridge in basis points
     */
    constructor(address _admin, address _wethOFT, uint32 _dstLzChainId, uint256 _slippageTolerance) {
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_wethOFT);

        if (_dstLzChainId == 0) {
            revert InvalidLzChainId();
        }

        if (_slippageTolerance > BASIS_POINTS_DIVISOR) {
            revert InvalidSlippageTolerance();
        }

        wethOFT = IOFT(_wethOFT);
        dstLzChainId = _dstLzChainId;
        slippageTolerance = _slippageTolerance;

        // Set the admin role
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice Sets the slippage tolerance for the bridge
     * @param newSlippageTolerance The new slippage tolerance in basis points
     */
    function setSlippageTolerance(uint256 newSlippageTolerance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSlippageTolerance > BASIS_POINTS_DIVISOR) {
            revert InvalidSlippageTolerance();
        }

        slippageTolerance = newSlippageTolerance;
        emit SlippageToleranceUpdated(newSlippageTolerance);
    }

    /**
     * @notice Bridges WETH from TAC to L1
     * @param recipient The address of the recipient on L1
     * @param amount The amount of wstETH to bridge
     */
    function bridgeTokenToL1(address recipient, uint256 amount) external payable nonReentrant {
        UtilLib.checkNonZeroAddress(recipient);

        if (amount == 0) {
            revert ZeroAmount();
        }

        // Calculate the native fee for bridging
        uint256 nativeFee = getNativeFee(amount, recipient);

        // Check if the msg.value is equal to the native fee for bridging
        if (msg.value != nativeFee) {
            revert InvalidNativeFee();
        }

        // Transfer the tokens to this contract
        IERC20(address(wethOFT)).safeTransferFrom(msg.sender, address(this), amount);

        // Bridge WETH to the L1 recipient
        SendParam memory sendParam = SendParam({
            dstEid: dstLzChainId,
            to: getReceiver(recipient),
            amountLD: amount,
            minAmountLD: getMinAmount(amount),
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = MessagingFee({ nativeFee: nativeFee, lzTokenFee: 0 });

        (, OFTReceipt memory oftReceipt) = wethOFT.send{ value: nativeFee }(sendParam, fee, msg.sender);

        emit BridgedWETHToL1(dstLzChainId, recipient, oftReceipt.amountSentLD, oftReceipt.amountReceivedLD);
    }

    /**
     * @dev Quote the native fee for sending WETH to L1
     * @param amount The amount of WETH to send
     * @param receiver The address of the receiver on L1
     * @return The fee to be paid in native currency
     */
    function getNativeFee(uint256 amount, address receiver) public view returns (uint256) {
        UtilLib.checkNonZeroAddress(receiver);

        if (amount == 0) {
            revert ZeroAmount();
        }

        SendParam memory sendParam = SendParam({
            dstEid: dstLzChainId,
            to: getReceiver(receiver),
            amountLD: amount,
            minAmountLD: getMinAmount(amount),
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = wethOFT.quoteSend(sendParam, false);

        return fee.nativeFee;
    }

    /**
     * @dev Get the minimum amount after slippage
     * @param amount The amount
     * @return The minimum amount after applying slippage
     */
    function getMinAmount(uint256 amount) public view returns (uint256) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 minAmount = amount * (BASIS_POINTS_DIVISOR - slippageTolerance) / BASIS_POINTS_DIVISOR;

        if (minAmount == 0) {
            revert InvalidMinAmount();
        }

        return minAmount;
    }

    /**
     * @dev Get the receiver address in the bytes32 format
     * @param receiver The address of the receiver on L1
     * @return The receiver address in the bytes32 format
     */
    function getReceiver(address receiver) public pure returns (bytes32) {
        UtilLib.checkNonZeroAddress(receiver);
        return bytes32(uint256(uint160(receiver)));
    }
}
