// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {
    ERC20Upgradeable, IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
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
import { IL2TokenBridge } from "contracts/interfaces/L2/IL2TokenBridge.sol";

interface IOracle {
    function getRate() external view returns (uint256);
}

interface IERC20WrsETH is IERC20Upgradeable {
    function mint(address to, uint256 amount) external;
}

/// @title RSETHPoolV3ExternalBridge
/// @notice This contract is the pool for swapping ETH for rsETH. It uses external bridges (e.g. LayerZero/Stargate) for
/// bridging ETH from L2s to L1 and native bridging for LSTs (e.g. wstETH).
contract RSETHPoolV3ExternalBridge is ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
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

    /// @notice ETH identifier address
    address public constant ETH_IDENTIFIER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The mapping of token addresses to the fee earned in that token
    mapping(address token => uint256 feeEarned) public feeEarnedInToken;

    /// @notice The mapping of token addresses to their respective oracle addresses
    mapping(address token => address oracle) public supportedTokenOracle;

    /// @notice The mapping of token addresses to their respective token bridges
    mapping(address token => address bridge) public tokenBridge;

    /// @notice An array of supported token addresses
    address[] public supportedTokenList;

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier whenPaused() {
        if (!paused) revert ContractNotPaused();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (supportedTokenOracle[token] == address(0)) revert UnsupportedToken();
        _;
    }

    /// @dev Modifier to enforce the daily minting limit
    /// @param amount The asset amount sent in the deposit
    /// @param token The token address
    modifier limitDailyMint(uint256 amount, address token) {
        if (block.timestamp < startTimestamp) {
            revert MintBeforeStartTimestamp();
        }

        uint256 rsETHAmount;

        // Calculate the amount of rsETH that will be minted
        if (token == ETH_IDENTIFIER) {
            (rsETHAmount,) = viewSwapRsETHAmountAndFee(amount);
        } else {
            (rsETHAmount,) = viewSwapRsETHAmountAndFee(amount, token);
        }

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

    /// @notice Custom errors
    error InvalidAmount();
    error TransferFailed();
    error InsufficientETHBalance();
    error InvalidMinAmount();
    error InsufficientNativeFee();
    error InvalidSlippageTolerance();
    error ContractPaused();
    error ContractNotPaused();
    error DailyMintLimitExceeded();
    error InvalidDailyMintLimit();
    error MintBeforeStartTimestamp();
    error InvalidStartTimestamp();
    error DeprecatedFunction();
    error InvalidLzChainId();
    error UnsupportedToken();
    error InvalidOracle();
    error AlreadySupportedToken();
    error TokenNotFoundError();
    error ZeroBridgeAmount();
    error MissingBridgeForToken();
    error InvalidFeeAmount();

    /// @notice Events
    event SwapOccurred(address indexed user, uint256 rsETHAmount, uint256 fee, string referralId);
    event SwapOccurred(
        address indexed user, uint256 rsETHAmount, uint256 fee, string referralId, address indexed depositedToken
    );
    event FeesWithdrawn(uint256 feeEarnedInETH);
    event FeesWithdrawn(uint256 feeEarnedInETH, address token);
    event BridgedETHToL1(uint32 lzChainId, address l1Receiver, uint256 amountSent, uint256 amountReceived);
    event BridgedTokenToL1(address indexed token, address l1Receiver, uint256 amountSent);
    event FeeBpsSet(uint256 feeBps);
    event OracleSet(address oracle);
    event AddSupportedToken(address token, address oracle, address bridge);
    event RemovedSupportedToken(address token);
    event L1VaultETHForL2ChainSet(address l1VaultETHForL2Chain);
    event StargatePoolSet(address stargatePool);
    event LzChainIdSet(uint32 lzChainId);
    event Paused(address account);
    event Unpaused(address account);
    event DailyMintLimitSet(uint256 dailyMintLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Reinitializer function to set the initial supported token
    /// @param token The token address
    /// @param oracle The oracle address
    /// @param bridge The bridge address
    function reinitialize(
        address token,
        address oracle,
        address bridge
    )
        external
        reinitializer(5)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _addSupportedToken(token, oracle, bridge);
    }

    /// @dev Reinitializer function to set the daily minting limit
    /// @param _dailyMintLimit The daily minting limit
    /// @param _startTimestamp The start timestamp for the daily minting limit
    function reinitialize(
        uint256 _dailyMintLimit,
        uint256 _startTimestamp
    )
        public
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
    function reinitialize(uint32 _dstLzChainId) public reinitializer(3) onlyRole(DEFAULT_ADMIN_ROLE) {
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
        public
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

        wrsETH = IERC20WrsETH(_wrsETH);
        feeBps = _feeBps;
        rsETHOracle = _rsETHOracle;
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
    function deposit(string memory referralId)
        external
        payable
        whenNotPaused
        nonReentrant
        limitDailyMint(msg.value, ETH_IDENTIFIER)
    {
        uint256 amount = msg.value;

        if (amount == 0) revert InvalidAmount();

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount);

        feeEarnedInETH += fee;

        wrsETH.mint(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId);
    }

    /// @dev Swaps supported token for rsETH
    /// @param token The token address
    /// @param amount The amount of token
    /// @param referralId The referral id
    function deposit(
        address token,
        uint256 amount,
        string memory referralId
    )
        external
        whenNotPaused
        nonReentrant
        onlySupportedToken(token)
        limitDailyMint(amount, token)
    {
        if (amount == 0) revert InvalidAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        (uint256 rsETHAmount, uint256 fee) = viewSwapRsETHAmountAndFee(amount, token);

        feeEarnedInToken[token] += fee;

        wrsETH.mint(msg.sender, rsETHAmount);

        emit SwapOccurred(msg.sender, rsETHAmount, fee, referralId, token);
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
     * @dev Quote the native fee for sending RsETH to L2
     * @param amount The amount of RsETH to send
     * @param minAmount The minimum amount of RsETH to receive on L2
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
    function getMinAmount(uint256 amount, uint256 slippageTolerance) public pure returns (uint256) {
        if (slippageTolerance > 100) revert InvalidSlippageTolerance();

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

    /*//////////////////////////////////////////////////////////////
                            ACCESS RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Withdraws fees earned by the pool in ETH
    function withdrawFees(address receiver) external onlyRole(BRIDGER_ROLE) {
        // withdraw fees in ETH
        uint256 amountToSendInETH = feeEarnedInETH;
        feeEarnedInETH = 0;
        (bool success,) = payable(receiver).call{ value: amountToSendInETH }("");
        if (!success) revert TransferFailed();

        emit FeesWithdrawn(amountToSendInETH);
    }

    /// @dev Withdraws fees earned by the pool in a specific token
    function withdrawFees(address receiver, address token) external onlySupportedToken(token) onlyRole(BRIDGER_ROLE) {
        // withdraw fees in token
        uint256 amountToSendInToken = feeEarnedInToken[token];
        feeEarnedInToken[token] = 0;
        IERC20(token).safeTransfer(receiver, amountToSendInToken);

        emit FeesWithdrawn(amountToSendInToken, token);
    }

    /// @dev Legacy function - Withdraws assets from the contract for bridging
    function moveAssetsForBridging() external view onlyRole(BRIDGER_ROLE) {
        revert DeprecatedFunction();
    }

    /// @dev Withdraws ETH from the L2 to L1 using LayerZero
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
        if (getETHBalanceMinusFees() < amount) {
            revert InsufficientETHBalance();
        }

        if (minAmount > amount || minAmount == 0) {
            revert InvalidMinAmount();
        }

        if (msg.value < nativeFee) {
            revert InsufficientNativeFee();
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

        uint256 balance = IERC20(token).balanceOf(address(this));

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

    /// @dev Sets the rsETHOracle address
    /// @param _rsETHOracle The rsETHOracle address
    function setRSETHOracle(address _rsETHOracle) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETHOracle);
        rsETHOracle = _rsETHOracle;
        emit OracleSet(_rsETHOracle);
    }

    /// @dev Adds a supported token
    /// @param token The token address
    /// @param oracle The oracle address
    /// @param bridge The bridge address
    function addSupportedToken(address token, address oracle, address bridge) external onlyRole(TIMELOCK_ROLE) {
        _addSupportedToken(token, oracle, bridge);
    }

    /// @dev Removes a supported token
    /// @param token The token address
    /// @param tokenIndex The index of the token in the supportedTokenList
    function removeSupportedToken(address token, uint256 tokenIndex) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(token);
        if (supportedTokenList[tokenIndex] != token) {
            revert TokenNotFoundError();
        }
        delete supportedTokenOracle[token];
        delete tokenBridge[token];
        supportedTokenList[tokenIndex] = supportedTokenList[supportedTokenList.length - 1];
        supportedTokenList.pop();
        emit RemovedSupportedToken(token);
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

    /// @dev Pauses the pausable methods in the contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        paused = true;
        emit Paused(msg.sender);
    }

    /// @dev Unpauses the pausable methods in the contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
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

    /// @dev Internal function to add a supported token
    function _addSupportedToken(address token, address oracle, address bridge) internal {
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
            revert InvalidOracle();
        }
        supportedTokenList.push(token);
        supportedTokenOracle[token] = oracle;
        tokenBridge[token] = bridge;

        emit AddSupportedToken(token, oracle, bridge);
    }
}
