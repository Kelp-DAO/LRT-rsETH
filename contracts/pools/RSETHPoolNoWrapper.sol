// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilLib } from "contracts/utils/UtilLib.sol";
import {
    IStargatePoolNative,
    SendParam,
    MessagingFee,
    OFTReceipt,
    MessagingReceipt,
    TxReceipt
} from "contracts/external/layerzero/interfaces/IStargatePoolNative.sol";
import { IL2Messenger } from "contracts/interfaces/L2/IL2Messenger.sol";
import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";

interface IOracle {
    function getRate() external view returns (uint256);
}

/// @title RSETHPoolNoWrapper
/// @notice This contract is the deposit pool for the chains where there is no rsETH wrapper contract (e.g. Arbitrum,
/// Unichain)
contract RSETHPoolNoWrapper is AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Roles
    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice The canonical rsETH token address (rsETH OFT)
    IERC20 public rsETH;

    /// @notice Basis points for fees
    uint256 public feeBps;

    /// @notice Fee earned in ETH
    uint256 public feeEarnedInETH;

    /// @notice The rsETHOracle address
    address public rsETHOracle;

    /// @notice Flag to enable/disable native ETH deposits
    bool public isEthDepositEnabled;

    /// @notice Mapping to track fees earned in different tokens
    mapping(address token => uint256 feeEarned) public feeEarnedInToken;

    /// @notice Mapping of supported tokens to their oracles
    mapping(address token => address oracle) public supportedTokenOracle;

    /// @notice Array of supported tokens
    address[] public supportedTokenList;

    /// @notice The corresponding L1Vault contract for the L2 chain
    address public l1VaultETHForL2Chain;

    /// @notice The StargatePool used for L2 --> L1 bridging
    IStargatePoolNative public stargatePool;

    /// @notice The LayerZero ID for the ETH mainnet
    uint32 public dstLzChainId;

    /// @notice The latest transaction receipt info from the StargatePoolNative
    TxReceipt public latestTxReceipt;

    /// @notice The mapping of token addresses to their respective token bridges
    mapping(address token => address bridge) public tokenBridge;

    /// @notice The address of the L2 bridge contract on Unichain
    address public l2Bridge;

    /// @notice The address of the Unichain messenger contract
    address public messenger;

    /// @notice The pauser role identifier
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Modifier to ensure the token is supported
    modifier onlySupportedToken(address token) {
        if (supportedTokenOracle[token] == address(0)) revert UnsupportedToken();
        _;
    }

    /// @notice Custom errors
    error InvalidAmount();
    error TransferFailed();
    error UnsupportedOracle();
    error UnsupportedToken();
    error AlreadySupportedToken();
    error TokenNotFoundError();
    error TokenBalanceNotZero();
    error EthDepositDisabled();
    error InsufficientETHBalance();
    error InvalidMinAmount();
    error IncorrectNativeFee();
    error InvalidSlippageTolerance();
    error DeprecatedFunction();
    error InvalidLzChainId();
    error InvalidFeeAmount();
    error ZeroBridgeAmount();
    error MissingBridgeForToken();

    /// @notice Events
    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event FeesWithdrawn(uint256 feeEarnedInETH, address token);
    event AssetsMovedForBridging(uint256 tokenBalanceMinusFees, address token);
    event BridgedETHToL1ViaNativeBridge(address indexed l1Receiver, uint256 ethBalanceMinusFees);
    event BridgedETHToL1(
        uint32 indexed lzChainId, address indexed l1Receiver, uint256 amountSent, uint256 amountReceived
    );
    event BridgedTokenToL1(address indexed token, address indexed l1Receiver, uint256 amountSent);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);
    event AddSupportedToken(address token, address oracle, address bridge);
    event RemovedSupportedToken(address token);
    event IsEthDepositEnabled(bool isEthDepositEnabled);
    event L1VaultETHForL2ChainSet(address l1VaultETHForL2Chain);
    event StargatePoolSet(address stargatePool);
    event LzChainIdSet(uint32 lzChainId);
    event L2BridgeSet(address l2Bridge);
    event MessengerSet(address messenger);
    event TokenOracleSet(address indexed token, address oracle);
    event TokenBridgeSet(address indexed token, address bridge);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Reinitializes the contract to enable native bridging of ETH from Unichain to ETH mainnet
     * @param _l2Bridge The address of the L2 bridge contract on Unichain
     * @param _messenger The address of the Unichain messenger contract
     */
    function reinitialize(address _l2Bridge, address _messenger)
        external
        reinitializer(3)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UtilLib.checkNonZeroAddress(_l2Bridge);
        UtilLib.checkNonZeroAddress(_messenger);

        l2Bridge = _l2Bridge;
        messenger = _messenger;

        emit L2BridgeSet(_l2Bridge);
        emit MessengerSet(_messenger);
    }

    /// @dev Reinitialize the contract
    /// @param _l1VaultETHForL2Chain The address of the L1VaultETH for the L2 chain
    /// @param _stargatePool The address of the StargatePool used for L2 --> L1 bridging
    /// @param _dstLzChainId The LayerZero ID for the ETH mainnet
    function reinitialize(
        address _l1VaultETHForL2Chain,
        address _stargatePool,
        uint32 _dstLzChainId
    )
        external
        reinitializer(2)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UtilLib.checkNonZeroAddress(_l1VaultETHForL2Chain);
        UtilLib.checkNonZeroAddress(_stargatePool);

        if (_dstLzChainId == 0) {
            revert InvalidLzChainId();
        }

        l1VaultETHForL2Chain = _l1VaultETHForL2Chain;
        stargatePool = IStargatePoolNative(_stargatePool);
        dstLzChainId = _dstLzChainId;
    }

    /// @dev Initialize the contract
    /// @param admin The admin address
    /// @param manager The manager address
    /// @param _rsETH The canonical rsETH token address (rsETH OFT)
    /// @param _feeBps The fee basis points
    /// @param _rsETHOracle The rsETHOracle address
    /// @param _isEthDepositEnabled Flag to enable/disable native ETH deposits
    function initialize(
        address admin,
        address manager,
        address _rsETH,
        uint256 _feeBps,
        address _rsETHOracle,
        bool _isEthDepositEnabled
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(admin);
        UtilLib.checkNonZeroAddress(manager);
        UtilLib.checkNonZeroAddress(_rsETH);
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(BRIDGER_ROLE, manager);

        rsETH = IERC20(_rsETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
        isEthDepositEnabled = _isEthDepositEnabled;
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
    function deposit(string memory referralId) external payable nonReentrant whenNotPaused {
        if (!isEthDepositEnabled) revert EthDepositDisabled();
        uint256 amount = msg.value;

        if (amount == 0) revert InvalidAmount();

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount);

        feeEarnedInETH += fee;

        rsETH.safeTransfer(msg.sender, rsETHAmount);

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
        whenNotPaused
        onlySupportedToken(token)
    {
        if (amount == 0) revert InvalidAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount, token);

        feeEarnedInToken[token] += fee;

        rsETH.safeTransfer(msg.sender, rsETHAmount);

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

    /**
     * @dev Quote the native fee for sending ETH to L1
     * @param amount The amount of ETH to send
     * @param minAmount The minimum amount of ETH to receive on L1 after slippage
     * @return The fee to be paid in native currency
     */
    function getNativeFee(uint256 amount, uint256 minAmount) external view returns (uint256) {
        if (minAmount > amount || minAmount == 0) {
            revert InvalidMinAmount();
        }

        SendParam memory sendParam = SendParam({
            dstEid: dstLzChainId,
            to: getReceiver(),
            amountLD: amount,
            minAmountLD: minAmount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = stargatePool.quoteSend(sendParam, false);

        return fee.nativeFee;
    }

    /**
     * @dev Get the receiver address in the bytes32 format
     * @return The receiver address in the bytes32 format
     */
    function getReceiver() public view returns (bytes32) {
        return bytes32(uint256(uint160(l1VaultETHForL2Chain)));
    }

    /**
     * @dev Get the ETH balance minus the fees
     * @return The ETH balance minus the fees
     */
    function getETHBalanceMinusFees() public view returns (uint256) {
        return address(this).balance - feeEarnedInETH;
    }

    /**
     * @dev Get the token balance minus the fees
     * @param token The token address
     * @return The token balance minus the fees
     */
    function getTokenBalanceMinusFees(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this)) - feeEarnedInToken[token];
    }

    /**
     * @dev Get the minimum amount after slippage
     * @param amount The amount
     * @param slippageTolerance The slippage tolerance
     * @return The minimum amount after slippage
     */
    function getMinAmount(uint256 amount, uint256 slippageTolerance) external pure returns (uint256) {
        if (slippageTolerance > 10_000) revert InvalidSlippageTolerance();

        return amount - (amount * slippageTolerance / 10_000);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(address receiver) external nonReentrant onlyRole(BRIDGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInETH = feeEarnedInETH;
        feeEarnedInETH = 0;
        (bool success,) = payable(receiver).call{ value: amountToSendInETH }("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(amountToSendInETH);
    }

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(
        address receiver,
        address token
    )
        external
        nonReentrant
        onlySupportedToken(token)
        onlyRole(BRIDGER_ROLE)
    {
        // withdraw fees in ETH
        uint256 amountToSendInToken = feeEarnedInToken[token];
        feeEarnedInToken[token] = 0;
        IERC20(token).safeTransfer(receiver, amountToSendInToken);

        emit FeesWithdrawn(amountToSendInToken, token);
    }

    /// @dev Legacy function - Withdraws assets from the contract for bridging
    function moveAssetsForBridging() external view onlyRole(BRIDGER_ROLE) {
        revert DeprecatedFunction();
    }

    /// @dev Legacy function - Withdraws assets from the contract for bridging
    function moveAssetsForBridging(address token)
        external
        nonReentrant
        onlySupportedToken(token)
        onlyRole(BRIDGER_ROLE)
    {
        // withdraw token - fees
        uint256 tokenBalanceMinusFees = IERC20(token).balanceOf(address(this)) - feeEarnedInToken[token];

        IERC20(token).safeTransfer(msg.sender, tokenBalanceMinusFees);

        emit AssetsMovedForBridging(tokenBalanceMinusFees, token);
    }

    /// @notice Withdraws ETH from Unichain to L1 using the Unichain's native bridge
    function bridgeAssetsViaNativeBridge() external nonReentrant onlyRole(BRIDGER_ROLE) {
        UtilLib.checkNonZeroAddress(l2Bridge);
        UtilLib.checkNonZeroAddress(messenger);
        UtilLib.checkNonZeroAddress(l1VaultETHForL2Chain);

        // withdraw ETH - fees
        uint256 ethBalanceMinusFees = getETHBalanceMinusFees();

        IL2Messenger(messenger).sendETHToL1ViaBridge{ value: ethBalanceMinusFees }(
            l2Bridge, l1VaultETHForL2Chain, ethBalanceMinusFees
        );

        emit BridgedETHToL1ViaNativeBridge(l1VaultETHForL2Chain, ethBalanceMinusFees);
    }

    /// @dev Withdraws assets from the L2 to L1 using LayerZero
    /// @param amount The amount of ETH to bridge
    /// @param minAmount The minimum amount of ETH to receive on L1
    /// @param nativeFee The native fee to pay for the bridge
    function bridgeAssets(
        uint256 amount,
        uint256 minAmount,
        uint256 nativeFee
    )
        external
        payable
        nonReentrant
        onlyRole(BRIDGER_ROLE)
    {
        // Exclude msg.value so reserved fees can’t be accidentally consumed
        if (getETHBalanceMinusFees() - msg.value < amount) {
            revert InsufficientETHBalance();
        }

        if (minAmount > amount || minAmount == 0) {
            revert InvalidMinAmount();
        }

        if (msg.value != nativeFee) {
            revert IncorrectNativeFee();
        }

        SendParam memory sendParam = SendParam({
            dstEid: dstLzChainId,
            to: getReceiver(),
            amountLD: amount,
            minAmountLD: minAmount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = MessagingFee({ nativeFee: nativeFee, lzTokenFee: 0 });

        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            stargatePool.send{ value: nativeFee + amount }(sendParam, fee, msg.sender);

        latestTxReceipt = TxReceipt({ guid: msgReceipt.guid, amountReceivedLD: oftReceipt.amountReceivedLD });

        emit BridgedETHToL1(dstLzChainId, l1VaultETHForL2Chain, oftReceipt.amountSentLD, oftReceipt.amountReceivedLD);
    }

    /// @dev Bridges tokens to L1 using their corresponding token bridge
    /// @param token The address of the token to bridge
    function bridgeTokens(address token)
        external
        payable
        nonReentrant
        onlySupportedToken(token)
        onlyRole(BRIDGER_ROLE)
    {
        if (tokenBridge[token] == address(0)) {
            revert MissingBridgeForToken();
        }

        uint256 balance = getTokenBalanceMinusFees(token);

        if (balance == 0) {
            revert ZeroBridgeAmount();
        }

        // Approve the required amount to the bridge
        IERC20(token).safeIncreaseAllowance(tokenBridge[token], balance);

        // Call the bridge contract to transfer the tokens (msg.value is included in case we need to pay for additional
        // bridging fees)
        IL2TokenBridge(tokenBridge[token]).bridgeTokenToL1{ value: msg.value }(l1VaultETHForL2Chain, balance);

        emit BridgedTokenToL1(token, l1VaultETHForL2Chain, balance);
    }

    /// @dev Sets the fee basis points
    /// @param _feeBps The fee basis points
    function setFeeBps(uint256 _feeBps) external onlyRole(TIMELOCK_ROLE) {
        if (_feeBps > 10_000) revert InvalidFeeAmount();

        feeBps = _feeBps;

        emit FeeBpsSet(_feeBps);
    }

    /// @dev Sets the isEthDepositEnabled flag
    /// @param _isEthDepositEnabled The isEthDepositEnabled flag
    function setIsEthDepositEnabled(bool _isEthDepositEnabled) external onlyRole(TIMELOCK_ROLE) {
        isEthDepositEnabled = _isEthDepositEnabled;
        emit IsEthDepositEnabled(_isEthDepositEnabled);
    }

    /// @dev Sets the rsETHOracle address
    /// @param _rsETHOracle The rsETHOracle address
    function setRSETHOracle(address _rsETHOracle) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETHOracle);

        rsETHOracle = _rsETHOracle;

        emit OracleSet(_rsETHOracle);
    }

    /// @dev Sets the new L1VaultETH for the L2 chain
    /// @param _l1VaultETHForL2Chain The new L1VaultETH for the L2 chain
    function setL1VaultETHForL2Chain(address _l1VaultETHForL2Chain) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_l1VaultETHForL2Chain);

        l1VaultETHForL2Chain = _l1VaultETHForL2Chain;

        emit L1VaultETHForL2ChainSet(_l1VaultETHForL2Chain);
    }

    /// @dev Sets the new stargatePool address
    /// @param _stargatePool The new stargatePool address
    function setStargatePool(address _stargatePool) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_stargatePool);

        stargatePool = IStargatePoolNative(_stargatePool);

        emit StargatePoolSet(_stargatePool);
    }

    /// @dev Adds a supported token
    /// @param token The token address
    /// @param oracle The oracle address for the token
    /// @param bridge The bridge address for the token
    function addSupportedToken(address token, address oracle, address bridge) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        UtilLib.checkNonZeroAddress(oracle);
        UtilLib.checkNonZeroAddress(bridge);

        if (supportedTokenOracle[token] != address(0)) {
            revert AlreadySupportedToken();
        }
        if (tokenBridge[token] != address(0)) {
            revert AlreadySupportedToken();
        }
        if (IOracle(oracle).getRate() == 0) {
            revert UnsupportedOracle();
        }
        supportedTokenList.push(token);
        supportedTokenOracle[token] = oracle;
        tokenBridge[token] = bridge;

        emit AddSupportedToken(token, oracle, bridge);
    }

    /// @dev Removes a supported token
    /// @param token The token address
    function removeSupportedToken(address token, uint256 tokenIndex) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        if (supportedTokenList[tokenIndex] != token) revert TokenNotFoundError();
        if (IERC20(token).balanceOf(address(this)) != 0) revert TokenBalanceNotZero();

        delete supportedTokenOracle[token];
        delete tokenBridge[token];
        supportedTokenList[tokenIndex] = supportedTokenList[supportedTokenList.length - 1];
        supportedTokenList.pop();
        emit RemovedSupportedToken(token);
    }

    /// @dev Sets the destination LayerZero chain ID
    /// @param _dstLzChainId The destination LayerZero chain ID
    function setDstLzChainId(uint32 _dstLzChainId) external onlyRole(TIMELOCK_ROLE) {
        if (_dstLzChainId == 0) {
            revert InvalidLzChainId();
        }

        dstLzChainId = _dstLzChainId;

        emit LzChainIdSet(_dstLzChainId);
    }

    /**
     * @notice Sets the new l2Bridge address
     * @param _l2Bridge The new l2Bridge address
     */
    function setL2Bridge(address _l2Bridge) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_l2Bridge);
        l2Bridge = _l2Bridge;
        emit L2BridgeSet(_l2Bridge);
    }

    /**
     * @notice Sets the L2 messenger address
     * @param _messenger The new L2 messenger address
     */
    function setMessenger(address _messenger) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_messenger);
        messenger = _messenger;
        emit MessengerSet(_messenger);
    }

    /**
     * @notice Sets the oracle for a specific token
     * @param token The token address
     * @param oracle The new oracle address for the token
     */
    function setSupportedTokenOracle(
        address token,
        address oracle
    )
        external
        onlyRole(TIMELOCK_ROLE)
        onlySupportedToken(token)
    {
        UtilLib.checkNonZeroAddress(oracle);
        if (IOracle(oracle).getRate() == 0) {
            revert UnsupportedOracle();
        }
        supportedTokenOracle[token] = oracle;
        emit TokenOracleSet(token, oracle);
    }

    /**
     * @notice Sets the token bridge address for a specific token
     * @param token The token address
     * @param bridge The new bridge address for the token
     */
    function setTokenBridge(address token, address bridge) external onlyRole(TIMELOCK_ROLE) onlySupportedToken(token) {
        UtilLib.checkNonZeroAddress(bridge);
        tokenBridge[token] = bridge;
        emit TokenBridgeSet(token, bridge);
    }

    /// @dev Pauses the pausable methods in the contract
    function pause() external onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /// @dev Unpauses the pausable methods in the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }
}
