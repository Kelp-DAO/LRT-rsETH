// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/**
 * @dev Struct representing token parameters for the OFT send() operation
 */
struct SendParam {
    uint32 dstEid; // Destination endpoint ID.
    bytes32 to; // Recipient address.
    uint256 amountLD; // Amount to send in local decimals
    uint256 minAmountLD; // Minimum amount to send in local decimals
    bytes extraOptions; // Additional options supplied by the caller to be used in the LayerZero message
    bytes composeMsg; // The composed message for the send() operation
    bytes oftCmd; // The OFT command to be executed, unused in default OFT implementations
}

/**
 * @dev Struct representing the messaging fee for the OFT send() operation
 */
struct MessagingFee {
    uint256 nativeFee; // The fee to be paid in native currency
    uint256 lzTokenFee; // The fee to be paid in ZRO tokens
}

/**
 * @dev Struct representing messaging receipt information
 */
struct MessagingReceipt {
    bytes32 guid; // The GUID of the message
    uint64 nonce; // The nonce of the message
    MessagingFee fee; // The fee paid for the message (native currency and LZ tokens)
}

/**
 * @dev Struct representing OFT receipt information
 */
struct OFTReceipt {
    uint256 amountSentLD; // Amount of tokens ACTUALLY debited from the sender in local decimals
    uint256 amountReceivedLD; // Amount of tokens to be received on the remote side
}

/// @title RSETH OFT Adapter Interface
/// @notice Interface for the RSETH OFT (Omnichain Fungible Token) Adapter, which integrates with LayerZero protocol
interface IRSETH_OFTAdapter {
    /// @notice Sends tokens to another chain
    /// @dev This function handles the cross-chain token transfer
    /// @param _sendParam Parameters for the send operation
    /// @param _fee Messaging fee for the LayerZero protocol
    /// @param _refundAddress Address to refund excess fees
    /// @return msgReceipt Receipt of the messaging operation
    /// @return oftReceipt Receipt of the OFT operation
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Quotes the fee for sending tokens to another chain
    /// @dev This function estimates the fee without executing the transfer
    /// @param _sendParam Parameters for the send operation
    /// @param _payInLzToken Whether to pay the fee in LZ tokens
    /// @return MessagingFee structure containing the estimated fees
    function quoteSend(SendParam calldata _sendParam, bool _payInLzToken) external view returns (MessagingFee memory);
}
