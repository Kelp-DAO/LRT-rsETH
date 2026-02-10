// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/// @title IKingProtocol - Interface for King Protocol
/// @notice Interface for depositing assets into King Protocol and receiving KING tokens
interface IKingProtocol {
    /// @notice Deposit multiple assets into King Protocol
    /// @param _tokens Array of token addresses to deposit
    /// @param _amounts Array of amounts to deposit
    /// @param _receiver Recipient of the minted share tokens
    function deposit(address[] memory _tokens, uint256[] memory _amounts, address _receiver) external;

    /// @notice Preview the expected share tokens and fees for a deposit
    /// @param _tokens Array of token addresses to deposit
    /// @param _amounts Array of amounts to deposit
    /// @return shareToMint Amount of share tokens to mint (after fees)
    /// @return depositFee Amount of deposit fee
    function previewDeposit(
        address[] memory _tokens,
        uint256[] memory _amounts
    )
        external
        view
        returns (uint256 shareToMint, uint256 depositFee);
}
