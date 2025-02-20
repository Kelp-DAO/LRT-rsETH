// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import { ILRTDepositPool } from "./interfaces/ILRTDepositPool.sol";
import { IRSETH } from "./interfaces/IRSETH.sol";
import { UtilLib } from "./utils/UtilLib.sol";
import { IRSETH_OFTAdapter, SendParam, MessagingFee } from "./interfaces/IRSETH_OFTAdapter.sol";

/**
 * @title L1VaultETH
 * @notice This contract is the receiver of the ETH deposits from the L2 bridger.
 * It will mint the RsETH tokens and send them to the RsETHTokenWrapper on the
 * corresponding L2 chain. There should be 1 L1VaultETH for each L2 chain.
 */
contract L1VaultETH is Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    ILRTDepositPool public lrtDepositPool;
    IRSETH public rsETH;
    IRSETH_OFTAdapter public oftAdapter;
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // the LayerZero ID of the corresponding L2 chain
    uint32 public dstLzChainId;
    // the address of the RsETHTokenWrapper on the corresponding L2 chain (intended target contract)
    address public l2Receiver;
    // description to identify the L1VaultETH for which L2 chain
    string public description;

    event BridgedRsETHToL2(uint32 lzChainId, address l2Receiver, uint256 amount, uint256 minAmount);

    error InvalidMinRSETHAmountExpected();
    error InsufficientRsETHBalance();
    error InvalidMinAmount();
    error InvalidLzChainId();

    /**
     * @dev Initialize the L1VaultETH contract
     * @param admin The address of the admin
     * @param _lrtDepositPool The address of the LRT deposit pool
     * @param _rsETH The address of the RsETH token
     * @param _oftAdapter The address of the OFT adapter
     * @param _dstLzChainId The LayerZero ID of the corresponding L2 chain
     * @param _l2Receiver The address of the RsETHTokenWrapper on the corresponding L2 chain
     * @param _description The description to identify the L1VaultETH for which L2 chain
     */
    function initialize(
        address admin,
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
        UtilLib.checkNonZeroAddress(admin);
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

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(MANAGER_ROLE, admin);

        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
        rsETH = IRSETH(_rsETH);
        oftAdapter = IRSETH_OFTAdapter(_oftAdapter);
    }

    /**
     * @dev Call depositETH on LRTDepositPool to get rsETH from the ETH within L1 vault
     */
    function depositETHForL1VaultETH() external payable nonReentrant onlyRole(MANAGER_ROLE) {
        address ethIdentifier = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
        uint256 balanceOfETH = address(this).balance;

        uint256 rsETHAmountToMint = lrtDepositPool.getRsETHAmountToMint(ethIdentifier, balanceOfETH);

        if (rsETHAmountToMint == 0) {
            revert InvalidMinRSETHAmountExpected();
        }

        lrtDepositPool.depositETH{ value: balanceOfETH }(rsETHAmountToMint, "");
    }

    /**
     * @dev Bridge RsETH to L2
     * @param amount The amount of RsETH to bridge
     * @param minAmount The minimum amount of RsETH to receive on L2
     */
    function bridgeRsETHToL2(uint256 amount, uint256 minAmount) external payable nonReentrant onlyRole(MANAGER_ROLE) {
        if (rsETH.balanceOf(address(this)) < amount) {
            revert InsufficientRsETHBalance();
        }

        if (minAmount > amount || minAmount == 0) {
            revert InvalidMinAmount();
        }

        rsETH.approve(address(oftAdapter), amount);

        SendParam memory sendParam = SendParam({
            dstEid: dstLzChainId,
            to: bytes32(uint256(uint160(l2Receiver))),
            amountLD: amount,
            minAmountLD: minAmount,
            extraOptions: bytes(""),
            composeMsg: bytes(""),
            oftCmd: bytes("")
        });

        MessagingFee memory fee = oftAdapter.quoteSend(sendParam, false);

        oftAdapter.send{ value: fee.nativeFee }(sendParam, fee, msg.sender);

        emit BridgedRsETHToL2(dstLzChainId, l2Receiver, amount, minAmount);
    }

    /**
     * @dev Set the LRT deposit pool address
     * @param _lrtDepositPool The address of the LRT deposit pool
     */
    function setLrtDepositPool(address _lrtDepositPool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_lrtDepositPool);
        lrtDepositPool = ILRTDepositPool(_lrtDepositPool);
    }

    /**
     * @dev Set the RsETH address
     * @param _rsETH The address of the RsETH token
     */
    function setRsETH(address _rsETH) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_rsETH);
        rsETH = IRSETH(_rsETH);
    }

    /**
     * @dev Set the OFT adapter address
     * @param _oftAdapter The address of the OFT adapter
     */
    function setOFTAdapter(address _oftAdapter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UtilLib.checkNonZeroAddress(_oftAdapter);
        oftAdapter = IRSETH_OFTAdapter(_oftAdapter);
    }
}
