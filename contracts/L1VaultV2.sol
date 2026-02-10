// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Client } from "contracts/external/chainlink/libraries/Client.sol";
import { ILRTDepositPool } from "contracts/interfaces/ILRTDepositPool.sol";
import { IRouterClient } from "contracts/external/chainlink/IRouterClient.sol";
import { IRSETH } from "contracts/interfaces/IRSETH.sol";
import { IRSETH_OFTAdapter, SendParam, MessagingFee } from "contracts/interfaces/IRSETH_OFTAdapter.sol";
import { UtilLib } from "contracts/utils/UtilLib.sol";
import { IWETH } from "contracts/external/weth/IWETH.sol";
import { IWstETH } from "contracts/external/lido/IWstETH.sol";

/**
 * @title L1VaultV2
 * @notice This contract is the receiver of the ETH and LST token deposits from
 * the L2 bridger. It will mint the rsETH tokens and send them to the RsETHTokenWrapper
 * on the corresponding L2 chain after bridging. There should be exactly one L1Vault for
 * each L2 chain.
 * @dev This version of the L1Vault contract supports both LayerZero and CCIP-based bridging
 *      for rsETH.
 */
contract L1VaultV2 is Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The type of the bridge used for bridging rsETH to L2
    enum BridgeType {
        LayerZero,
        CCIP
    }

    /// @notice The address of the LRT deposit pool
    ILRTDepositPool public lrtDepositPool;

    /// @notice The address of the rsETH token
    IRSETH public rsETH;

    /// @notice The address of the RsETHTokenWrapper on the corresponding L2 chain
    IRSETH_OFTAdapter public oftAdapter;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant TIMELOCK_ROLE = keccak256("TIMELOCK_ROLE");

    /// @notice The LayerZero ID of the corresponding L2 chain
    uint32 public dstLzChainId;

    /// @notice The address of the RsETHTokenWrapper on the corresponding L2 chain (intended target contract)
    address public l2Receiver;

    /// @notice Description to identify for which L2 chain this L1Vault contract is used
    string public description;

    /// @notice The identifier for ETH in the LRT deposit pool
    address public constant ETH_IDENTIFIER = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice The address of the wstETH token
    address public wstETH;

    /// @notice The address of the WETH token
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice The Chainlink CCIP Router contract
    IRouterClient public ccipRouter;

    /// @notice The CCIP destination chain selector
    uint64 public destinationChainSelector;

    /// @notice The currently active bridge type
    BridgeType public bridgeType;

    /// @notice The default gas limit for the callback on the destination chain
    uint256 public ccipGasLimit;

    /// @notice Custom errors
    error InvalidMinRSETHAmountExpected();
    error InsufficientRsETHBalance();
    error ZeroAmount();
    error InvalidMinAmount();
    error InvalidLzChainId();
    error EmptyDescription();
    error IncorrectNativeFee();
    error NoWstETHBalance();
    error NoWETHBalance();
    error InvalidCCIPDestinationChainSelector();
    error IncorrectCCIPFee();
    error InactiveBridgeType();
    error InvalidBridgeType();
    error InvalidCcipGasLimit();

    /// @notice Events
    event ETHDepositForL1Vault(uint256 depositAmount, uint256 rsethMintAmount);
    event AssetDepositForL1Vault(address indexed asset, uint256 depositAmount, uint256 rsethMintAmount);
    event BridgedRsETHToL2(uint32 lzChainId, address l2Receiver, uint256 amount, uint256 minAmount);
    event BridgedRsETHToL2UsingCCIP(
        uint64 indexed destinationChainSelector, address indexed l2Receiver, uint256 amount, bytes32 messageId
    );
    event LRTDepositPoolSet(address lrtDepositPool);
    event RsETHSet(address rsETH);
    event OFTAdapterSet(address oftAdapter);
    event DstLzChainIdSet(uint32 dstLzChainId);
    event L2ReceiverSet(address l2Receiver);
    event DescriptionSet(string description);
    event WstETHSet(address wstETH);
    event WstETHUnwrapped(uint256 stETHAmount);
    event WETHUnwrapped(uint256 wethAmount);
    event CCIPRouterSet(address ccipRouter);
    event DestinationChainSelectorSet(uint64 destinationChainSelector);
    event BridgeTypeSet(BridgeType bridgeType);
    event CcipGasLimitSet(uint256 ccipGasLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Reinitializes the L1Vault contract with CCIP Router and destination chain selector
     * @param _ccipRouter The address of the CCIP Router
     * @param _destinationChainSelector The destination chain selector for CCIP
     * @param _bridgeType The type of the bridge to be used (LayerZero or CCIP)
     * @param _ccipGasLimit The gas limit for the callback on the destination chain (recommended value is 200,000)
     */
    function reinitialize(
        address _ccipRouter,
        uint64 _destinationChainSelector,
        BridgeType _bridgeType,
        uint256 _ccipGasLimit
    )
        external
        reinitializer(3)
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UtilLib.checkNonZeroAddress(_ccipRouter);
        if (_destinationChainSelector == 0) {
            revert InvalidCCIPDestinationChainSelector();
        }
        if (_bridgeType != BridgeType.LayerZero && _bridgeType != BridgeType.CCIP) {
            revert InvalidBridgeType();
        }
        if (_ccipGasLimit == 0) {
            revert InvalidCcipGasLimit();
        }

        ccipRouter = IRouterClient(_ccipRouter);
        destinationChainSelector = _destinationChainSelector;
        bridgeType = _bridgeType;
        ccipGasLimit = _ccipGasLimit;

        emit CCIPRouterSet(_ccipRouter);
        emit DestinationChainSelectorSet(_destinationChainSelector);
        emit BridgeTypeSet(_bridgeType);
        emit CcipGasLimitSet(_ccipGasLimit);
    }

    /**
     * @dev Reinitializes the L1Vault contract
     * @param _wstETH The address of the wstETH token
     */
    function reinitialize(address _wstETH) external reinitializer(2) onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_wstETH);
        wstETH = _wstETH;
        emit WstETHSet(_wstETH);
    }

    /**
     * @dev Initializes the L1Vault contract
     * @param _admin The address of the admin
     * @param _manager The address of the manager
     * @param _lrtDepositPool The address of the LRT deposit pool
     * @param _rsETH The address of the rsETH token
     * @param _oftAdapter The address of the OFT adapter
     * @param _dstLzChainId The LayerZero ID of the corresponding L2 chain
     * @param _l2Receiver The address of the RsETHTokenWrapper on the corresponding L2 chain
     * @param _description The description to identify the L1Vault for which L2 chain
     */
    function initialize(
        address _admin,
        address _manager,
        address _lrtDepositPool,
        address _rsETH,
        address _oftAdapter,
        uint32 _dstLzChainId,
        address _l2Receiver,
        string memory _description
    )
        external
        initializer
    {
        UtilLib.checkNonZeroAddress(_lrtDepositPool);
        UtilLib.checkNonZeroAddress(_rsETH);
        UtilLib.checkNonZeroAddress(_admin);
        UtilLib.checkNonZeroAddress(_manager);
        UtilLib.checkNonZeroAddress(_oftAdapter);
        UtilLib.checkNonZeroAddress(_l2Receiver);

        if (_dstLzChainId == 0) {
            revert InvalidLzChainId();
        }

        dstLzChainId = _dstLzChainId;
        l2Receiver = _l2Receiver;
        description = _description;

        __ReentrancyGuard_init();
        __AccessControl_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(MANAGER_ROLE, _manager);

        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
        rsETH = IRSETH(_rsETH);
        oftAdapter = IRSETH_OFTAdapter(_oftAdapter);
    }

    /**
     * @dev Call depositETH on LRTDepositPool to get rsETH from the ETH held within L1 vault
     */
    function depositETHForL1VaultETH() external payable nonReentrant onlyRole(MANAGER_ROLE) {
        uint256 balanceOfETH = address(this).balance;
        uint256 rsETHAmountToMint = lrtDepositPool.getRsETHAmountToMint(ETH_IDENTIFIER, balanceOfETH);

        if (rsETHAmountToMint == 0) {
            revert InvalidMinRSETHAmountExpected();
        }

        lrtDepositPool.depositETH{ value: balanceOfETH }(rsETHAmountToMint, "");

        emit ETHDepositForL1Vault(balanceOfETH, rsETHAmountToMint);
    }

    /**
     * @dev Call depositAsset on LRTDepositPool to get rsETH from the LSTs held within L1 vault
     */
    function depositAssetForL1Vault(address token) external nonReentrant onlyRole(MANAGER_ROLE) {
        UtilLib.checkNonZeroAddress(token);

        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        uint256 rsETHAmountToMint = lrtDepositPool.getRsETHAmountToMint(token, tokenBalance);

        if (rsETHAmountToMint == 0) {
            revert InvalidMinRSETHAmountExpected();
        }

        // Approve the LRT deposit pool to transfer the token
        IERC20(token).safeIncreaseAllowance(address(lrtDepositPool), tokenBalance);

        lrtDepositPool.depositAsset(token, tokenBalance, rsETHAmountToMint, "");

        emit AssetDepositForL1Vault(token, tokenBalance, rsETHAmountToMint);
    }

    /// @notice Unwrap wstETH to stETH to be able to mint rsETH
    function unwrapWstETH() external nonReentrant onlyRole(MANAGER_ROLE) {
        uint256 wstETHBalance = IERC20(wstETH).balanceOf(address(this));

        if (wstETHBalance == 0) {
            revert NoWstETHBalance();
        }

        // Unwrap wstETH to stETH
        uint256 stETHAmount = IWstETH(wstETH).unwrap(wstETHBalance);

        emit WstETHUnwrapped(stETHAmount);
    }

    /// @notice Unwrap WETH to ETH to be able to mint rsETH
    function unwrapWETH() external nonReentrant onlyRole(MANAGER_ROLE) {
        uint256 wethBalance = IERC20(WETH).balanceOf(address(this));

        if (wethBalance == 0) {
            revert NoWETHBalance();
        }

        // Unwrap WETH to ETH
        IWETH(WETH).withdraw(wethBalance);

        emit WETHUnwrapped(wethBalance);
    }

    /**
     * @dev Bridge rsETH to L2 using LayerZero
     * @param amount The amount of rsETH to bridge
     * @param minAmount The minimum amount of rsETH to receive on L2
     * @param nativeFee The native fee to pay for the bridge
     */
    function bridgeRsETHToL2(
        uint256 amount,
        uint256 minAmount,
        uint256 nativeFee
    )
        external
        payable
        nonReentrant
        onlyRole(MANAGER_ROLE)
    {
        if (bridgeType != BridgeType.LayerZero) {
            revert InactiveBridgeType();
        }

        if (rsETH.balanceOf(address(this)) < amount) {
            revert InsufficientRsETHBalance();
        }

        if (minAmount > amount || minAmount == 0) {
            revert InvalidMinAmount();
        }

        if (msg.value != nativeFee) {
            revert IncorrectNativeFee();
        }

        IERC20(address(rsETH)).safeIncreaseAllowance(address(oftAdapter), amount);

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

        oftAdapter.send{ value: nativeFee }(sendParam, fee, msg.sender);

        emit BridgedRsETHToL2(dstLzChainId, l2Receiver, amount, minAmount);
    }

    /**
     * @dev Bridge rsETH to L2 using CCIP
     * @param amount The amount of rsETH to bridge
     */
    function bridgeRsETHToL2UsingCCIP(uint256 amount) external payable nonReentrant onlyRole(MANAGER_ROLE) {
        if (bridgeType != BridgeType.CCIP) {
            revert InactiveBridgeType();
        }

        if (rsETH.balanceOf(address(this)) < amount) {
            revert InsufficientRsETHBalance();
        }

        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 fee = getCCIPFee(amount);

        if (msg.value != fee) {
            revert IncorrectCCIPFee();
        }

        IERC20(address(rsETH)).safeIncreaseAllowance(address(ccipRouter), amount);

        Client.EVM2AnyMessage memory message = getCCIPMessage(amount);

        bytes32 messageId = ccipRouter.ccipSend{ value: msg.value }(destinationChainSelector, message);

        emit BridgedRsETHToL2UsingCCIP(destinationChainSelector, l2Receiver, amount, messageId);
    }

    /**
     * @dev Quote the native fee for sending rsETH to L2
     * @param amount The amount of rsETH to send
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

        MessagingFee memory fee = oftAdapter.quoteSend(sendParam, false);

        return fee.nativeFee;
    }

    /**
     * @dev Get the CCIP fee for sending rsETH to L2
     * @param amount The amount of rsETH to send
     * @return The fee to be paid in native currency
     */
    function getCCIPFee(uint256 amount) public view returns (uint256) {
        Client.EVM2AnyMessage memory message = getCCIPMessage(amount);

        return ccipRouter.getFee(destinationChainSelector, message);
    }

    /**
     * @dev Get the CCIP message for sending rsETH to L2
     * @param amount The amount of rsETH to send
     * @return The CCIP message containing the receiver, data, token amounts, fee token, and extra args
     */
    function getCCIPMessage(uint256 amount) public view returns (Client.EVM2AnyMessage memory) {
        if (amount == 0) {
            revert ZeroAmount();
        }

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({ token: address(rsETH), amount: amount });

        Client.EVMExtraArgsV2 memory extraArgs = Client.EVMExtraArgsV2({
            gasLimit: ccipGasLimit,
            allowOutOfOrderExecution: true // Whether the message can be executed in any order relative to other
            // messages from the same sender
        });

        return Client.EVM2AnyMessage({
            receiver: abi.encodePacked(getReceiver()),
            data: bytes(""),
            tokenAmounts: tokenAmounts,
            feeToken: address(0), // address(0) means we will send msg.value (i.e. pay fee in native currency)
            extraArgs: Client._argsToBytes(extraArgs)
        });
    }

    /**
     * @dev Get the receiver address in the bytes32 format
     * @return The receiver address in the bytes32 format
     */
    function getReceiver() public view returns (bytes32) {
        return bytes32(uint256(uint160(l2Receiver)));
    }

    /**
     * @dev Set the LRT deposit pool address
     * @param _lrtDepositPool The address of the LRT deposit pool
     */
    function setLrtDepositPool(address _lrtDepositPool) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_lrtDepositPool);
        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
        emit LRTDepositPoolSet(_lrtDepositPool);
    }

    /**
     * @dev Set the rsETH address
     * @param _rsETH The address of the rsETH token
     */
    function setRsETH(address _rsETH) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETH);
        rsETH = IRSETH(_rsETH);
        emit RsETHSet(_rsETH);
    }

    /**
     * @dev Set the OFT adapter address
     * @param _oftAdapter The address of the OFT adapter
     */
    function setOFTAdapter(address _oftAdapter) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_oftAdapter);
        oftAdapter = IRSETH_OFTAdapter(_oftAdapter);
        emit OFTAdapterSet(_oftAdapter);
    }

    /**
     * @dev Sets the destination LayerZero chain ID
     * @param _dstLzChainId The LayerZero chain ID of the corresponding L2 chain
     */
    function setDstLzChainId(uint32 _dstLzChainId) external onlyRole(TIMELOCK_ROLE) {
        if (_dstLzChainId == 0) {
            revert InvalidLzChainId();
        }
        dstLzChainId = _dstLzChainId;
        emit DstLzChainIdSet(_dstLzChainId);
    }

    /**
     * @dev Sets the L2 receiver address
     * @param _l2Receiver The address of the RsETHTokenWrapper on the corresponding L2 chain
     */
    function setL2Receiver(address _l2Receiver) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_l2Receiver);
        l2Receiver = _l2Receiver;
        emit L2ReceiverSet(_l2Receiver);
    }

    /**
     * @dev Sets the description of the L1Vault contract
     * @param _description The description to identify the L1Vault for which L2 chain is used
     */
    function setDescription(string calldata _description) external onlyRole(TIMELOCK_ROLE) {
        if (bytes(_description).length == 0) {
            revert EmptyDescription();
        }
        description = _description;
        emit DescriptionSet(_description);
    }

    /**
     * @dev Sets the wstETH address
     * @param _wstETH The address of the wstETH token
     */
    function setWstETH(address _wstETH) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_wstETH);
        wstETH = _wstETH;
        emit WstETHSet(_wstETH);
    }

    /**
     * @dev Set the CCIP Router address
     * @param _ccipRouter The address of the CCIP Router
     */
    function setCCIPRouter(address _ccipRouter) external onlyRole(TIMELOCK_ROLE) {
        UtilLib.checkNonZeroAddress(_ccipRouter);
        ccipRouter = IRouterClient(_ccipRouter);
        emit CCIPRouterSet(_ccipRouter);
    }

    /**
     * @dev Sets the destination chain selector for CCIP
     * @param _destinationChainSelector The destination chain selector for CCIP
     */
    function setDestinationChainSelector(uint64 _destinationChainSelector) external onlyRole(TIMELOCK_ROLE) {
        if (_destinationChainSelector == 0) {
            revert InvalidCCIPDestinationChainSelector();
        }
        destinationChainSelector = _destinationChainSelector;
        emit DestinationChainSelectorSet(_destinationChainSelector);
    }

    /**
     * @dev Sets the bridge type (LayerZero or CCIP) to actively use for bridging rsETH to L2
     * @param _bridgeType The type of the bridge to be used
     */
    function setBridgeType(BridgeType _bridgeType) external onlyRole(TIMELOCK_ROLE) {
        if (_bridgeType != BridgeType.LayerZero && _bridgeType != BridgeType.CCIP) {
            revert InvalidBridgeType();
        }
        bridgeType = _bridgeType;
        emit BridgeTypeSet(_bridgeType);
    }

    /**
     * @dev Sets the default gas limit for the callback on the destination chain for CCIP
     * @param _ccipGasLimit The gas limit for the callback on the destination chain
     */
    function setCcipGasLimit(uint256 _ccipGasLimit) external onlyRole(TIMELOCK_ROLE) {
        if (_ccipGasLimit == 0) {
            revert InvalidCcipGasLimit();
        }
        ccipGasLimit = _ccipGasLimit;
        emit CcipGasLimitSet(_ccipGasLimit);
    }

    /// @dev Handles direct ETH transfers from the L2 bridge
    receive() external payable { }
}
