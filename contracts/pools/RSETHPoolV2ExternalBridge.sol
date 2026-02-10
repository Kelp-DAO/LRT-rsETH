// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {
    ERC20Upgradeable,
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
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

interface IOracle {
    function getRate() external view returns (uint256);
}

interface IERC20WrsETH is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;
}

interface IRsETHTokenWrapper {
    function allowedTokens(address asset) external view returns (bool);
    function maxAmountToDepositBridgerAsset(address asset) external view returns (uint256);
}

/// @title RSETHPoolV2ExternalBridge
/// @notice This contract is the pool for swapping ETH for rsETH. It uses external bridges (e.g. LayerZero/Stargate) for
/// bridging ETH between chains instead of native bridging.
contract RSETHPoolV2ExternalBridge is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IERC20WrsETH public wrsETH;
    uint256 public feeBps; // Basis points for fees
    uint256 public feeEarnedInETH;
    address public rsETHOracle;

    bytes32 public constant BRIDGER_ROLE = keccak256("BRIDGER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice The corresponding L1Vault contract for the L2 chain
    address public l1VaultETHForL2Chain;
    /// @notice The StargatePool used for L2 --> L1 bridging
    IStargatePoolNative public stargatePool;
    /// @notice The LayerZero ID for the ETH mainnet
    uint32 public dstLzChainId;

    /// @notice The latest transaction receipt info from the StargatePoolNative
    TxReceipt public latestTxReceipt;

    /// @notice New variable added for pausable functionality
    bool public paused;

    /// @notice THe daily minting limit for rsETH
    uint256 public dailyMintLimit;

    /// @notice The amount of rsETH that was minted today
    uint256 public dailyMintAmount;

    /// @notice The last day that rsETH was minted
    uint256 public lastMintDay;

    /// @notice The start timestamp for the daily minting limit
    uint256 public startTimestamp;

    /// @notice The address of the L2 bridge contract
    address public l2Bridge;

    /// @notice The address of the L2 messenger contract
    address public messenger;

    /// @notice The pauser role identifier
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The operator role identifier
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice The whitelisted user role identifier
    bytes32 public constant WHITELISTED_USER_ROLE = keccak256("WHITELISTED_USER_ROLE");

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    /// @dev Modifier to enforce the daily minting limit
    /// @param amount The ETH amount sent in the deposit
    modifier limitDailyMint(uint256 amount) {
        if (block.timestamp < startTimestamp) {
            revert MintBeforeStartTimestamp();
        }

        // Calculate the amount of rsETH that will be minted
        (uint256 rsETHAmount,) = viewSwapRsETHAmountAndFee(amount);
        uint256 currentDay = getCurrentDay();

        // If the current day is greater than the last mint day, reset the daily mint amount
        if (currentDay > lastMintDay) {
            lastMintDay = currentDay;
            dailyMintAmount = 0;
        }

        // Check if the daily mint amount plus the amount to mint is greater than the daily mint limit
        if (dailyMintAmount + rsETHAmount > dailyMintLimit) {
            revert DailyMintLimitExceeded();
        }

        dailyMintAmount += rsETHAmount;
        _;
    }

    /// @dev Modifier to restrict access to only the operator role or whitelisted users
    /// @param account The address to check
    modifier onlyOperatorOrWhitelisted(address account) {
        if (!hasRole(OPERATOR_ROLE, account) && !hasRole(WHITELISTED_USER_ROLE, account)) {
            revert NotOperatorOrWhitelisted();
        }
        _;
    }

    error InvalidAmount();
    error TransferFailed();
    error InsufficientETHBalance();
    error InvalidMinAmount();
    error IncorrectNativeFee();
    error InvalidSlippageTolerance();
    error ContractPaused();
    error ContractNotPaused();
    error DailyMintLimitExceeded();
    error InvalidDailyMintLimit();
    error MintBeforeStartTimestamp();
    error InvalidStartTimestamp();
    error InvalidLzChainId();
    error InvalidFeeAmount();
    error DeprecatedFunction();
    error UnsupportedOracle();
    error TokenNotAllowedInWrapper();
    error ExceedsMaxAmountToDepositInWrapper();
    error InsufficientETHBalanceForReverseSwap();
    error InsufficientBalanceInPool();
    error NotOperatorOrWhitelisted();

    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event ReverseSwapOccurred(address indexed user, address indexed rsETH, uint256 rsETHAmount, uint256 tokenAmount);
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event AssetsMovedForBridging(uint256 amount);
    event BridgedETHToL1ViaNativeBridge(address indexed l1Receiver, uint256 amount);
    event BridgedETHToL1(uint32 lzChainId, address l1Receiver, uint256 amountSent, uint256 amountReceived);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);
    event L1VaultETHForL2ChainSet(address l1VaultETHForL2Chain);
    event StargatePoolSet(address stargatePool);
    event LzChainIdSet(uint32 lzChainId);
    event Paused(address account);
    event Unpaused(address account);
    event DailyMintLimitSet(uint256 dailyMintLimit);
    event L2BridgeSet(address l2Bridge);
    event MessengerSet(address messenger);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Reinitializes the contract to enable native bridging of ETH
     * @param _l2Bridge The address of the L2 bridge contract
     * @param _messenger The address of the L2 messenger contract
     */
    function reinitialize(address _l2Bridge, address _messenger)
        external
        reinitializer(5)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UtilLib.checkNonZeroAddress(_l2Bridge);
        UtilLib.checkNonZeroAddress(_messenger);

        l2Bridge = _l2Bridge;
        messenger = _messenger;

        emit L2BridgeSet(_l2Bridge);
        emit MessengerSet(_messenger);
    }

    /// @dev Reinitializer function to set the daily minting limit
    /// @param _dailyMintLimit The daily minting limit
    /// @param _startTimestamp The start timestamp for the daily minting limit
    function reinitialize(
        uint256 _dailyMintLimit,
        uint256 _startTimestamp
    )
        external
        reinitializer(4)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_dailyMintLimit == 0) {
            revert InvalidDailyMintLimit();
        }

        // startTimestamp cannot be in the past
        if (block.timestamp > _startTimestamp) {
            revert InvalidStartTimestamp();
        }

        dailyMintLimit = _dailyMintLimit;
        startTimestamp = _startTimestamp;
    }

    /// @dev Reinitialize the contract
    /// @param _dstLzChainId The LayerZero ID for the ETH mainnet
    function reinitialize(uint32 _dstLzChainId) external reinitializer(3) onlyRole(DEFAULT_ADMIN_ROLE) {
        dstLzChainId = _dstLzChainId;
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

        l1VaultETHForL2Chain = _l1VaultETHForL2Chain;
        stargatePool = IStargatePoolNative(_stargatePool);
        dstLzChainId = _dstLzChainId;
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
        external
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

        wrsETH = IERC20WrsETH(_wrsETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
    }

    /// @dev Gets the rate from the rsETHOracle
    function getRate() public view returns (uint256) {
        return IOracle(rsETHOracle).getRate();
    }

    /// @dev Swaps ETH for rsETH
    /// @param referralId The referral id
    function deposit(string memory referralId) external payable nonReentrant whenNotPaused limitDailyMint(msg.value) {
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
     * @dev Get the minimum amount after slippage
     * @param amount The amount
     * @param slippageTolerance The slippage tolerance
     * @return The minimum amount after slippage
     */
    function getMinAmount(uint256 amount, uint256 slippageTolerance) external pure returns (uint256) {
        if (slippageTolerance > 10_000) revert InvalidSlippageTolerance();

        return amount - (amount * slippageTolerance / 10_000);
    }

    /// @notice Gets the current day relative to the start timestamp
    /// @return uint256 The current day relative to the start timestamp
    function getCurrentDay() public view returns (uint256) {
        return (block.timestamp - startTimestamp) / 1 days;
    }

    /// @notice Gets the remaining daily minting limit
    /// @return uint256 The remaining daily minting limit
    function remainingDailyMintLimit() external view returns (uint256) {
        // If we're on a new day but no mint has occurred yet, treat dailyMintAmount as 0
        uint256 effectiveDailyMintAmount = (getCurrentDay() > lastMintDay) ? 0 : dailyMintAmount;

        return dailyMintLimit - effectiveDailyMintAmount;
    }

    /// @notice Gets the next daily mint limit reset timestamp
    /// @return uint256 The next daily mint limit reset timestamp
    function getNextDailyLimitResetTimestamp() external view returns (uint256) {
        return startTimestamp + (getCurrentDay() + 1) * 1 days;
    }

    /**
     * @notice View quote for swapping minted rsETH to a supported pool asset
     * @dev Functionally, it works as the opposite of `viewSwapRsETHAmountAndFee`
     * @param rsETHAmount Amount of rsETH to swap.
     * @return ethAmount Amount of ETH the caller would receive.
     */
    function viewSwapAssetToPremintedRsETH(uint256 rsETHAmount) public view returns (uint256 ethAmount) {
        // Rate of rsETH in ETH
        uint256 rsETHToETHrate = getRate();
        if (rsETHToETHrate == 0) revert UnsupportedOracle();

        // Calculate the amount of token user will get for the amount of rsETH
        ethAmount = rsETHAmount * rsETHToETHrate / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                            ACCESS RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Operator-only swap from minted rsETH to ETH from the pool
     * @dev Functionally, it works as the opposite of `deposit`, but it does not charge any fees
     * @param rsETH Address of the rsETH token on this chain (must be allowed in wrapper)
     * @param rsETHAmount Amount of rsETH to swap for ETH
     */
    function swapAssetToPremintedRsETH(
        address rsETH,
        uint256 rsETHAmount
    )
        external
        nonReentrant
        onlyOperatorOrWhitelisted(msg.sender)
    {
        UtilLib.checkNonZeroAddress(rsETH);

        IRsETHTokenWrapper wrapper = IRsETHTokenWrapper(address(wrsETH));

        if (!wrapper.allowedTokens(rsETH)) revert TokenNotAllowedInWrapper();
        if (rsETHAmount == 0) revert InvalidAmount();
        if (rsETHAmount > wrapper.maxAmountToDepositBridgerAsset(rsETH)) revert ExceedsMaxAmountToDepositInWrapper();

        // Get the amount of ETH to transfer to the user for the given amount of rsETH provided
        uint256 ethAmount = viewSwapAssetToPremintedRsETH(rsETHAmount);

        // Transfer rsETH from sender to the wrapper
        IERC20(rsETH).safeTransferFrom(msg.sender, address(wrapper), rsETHAmount);

        // Transfer the ETH from the pool to the sender
        if (getETHBalanceMinusFees() < ethAmount) revert InsufficientETHBalanceForReverseSwap();
        (bool success,) = payable(msg.sender).call{ value: ethAmount }("");
        if (!success) revert TransferFailed();

        emit ReverseSwapOccurred(msg.sender, rsETH, rsETHAmount, ethAmount);
    }

    /// @dev Withdraws fees earned by the pool
    function withdrawFees(address receiver) external nonReentrant onlyRole(BRIDGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInETH = feeEarnedInETH;
        feeEarnedInETH = 0;
        (bool success,) = payable(receiver).call{ value: amountToSendInETH }("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(amountToSendInETH);
    }

    /// @dev Withdraws assets from the contract for bridging
    function moveAssetsForBridging() external view onlyRole(BRIDGER_ROLE) {
        revert DeprecatedFunction();
    }

    /// @notice Withdraws ETH from L2 to L1 using the L2's native bridge
    /// @param amount The amount of ETH to bridge via the native bridge
    function bridgeAssetsViaNativeBridge(uint256 amount) external nonReentrant onlyRole(BRIDGER_ROLE) {
        UtilLib.checkNonZeroAddress(l2Bridge);
        UtilLib.checkNonZeroAddress(messenger);
        UtilLib.checkNonZeroAddress(l1VaultETHForL2Chain);

        if (amount == 0) revert InvalidAmount();

        // bridge up to the ETH balance minus fees
        uint256 ethBalanceMinusFees = getETHBalanceMinusFees();
        if (amount > ethBalanceMinusFees) revert InsufficientETHBalance();

        IL2Messenger(messenger).sendETHToL1ViaBridge{ value: amount }(l2Bridge, l1VaultETHForL2Chain, amount);

        emit BridgedETHToL1ViaNativeBridge(l1VaultETHForL2Chain, amount);
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

    /// @dev Sets the fee basis points
    /// @param _feeBps The fee basis points
    function setFeeBps(uint256 _feeBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeBps > 1000) revert InvalidFeeAmount();
        feeBps = _feeBps;
        emit FeeBpsSet(_feeBps);
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

    /// @dev Pauses the pausable methods in the contract
    function pause() external onlyRole(PAUSER_ROLE) whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @dev Unpauses the pausable methods in the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @dev Sets the daily minting limit
    /// @param _dailyMintLimit The new daily minting limit
    function setDailyMintLimit(uint256 _dailyMintLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_dailyMintLimit == 0) {
            revert InvalidDailyMintLimit();
        }
        dailyMintLimit = _dailyMintLimit;
        emit DailyMintLimitSet(_dailyMintLimit);
    }
}
