// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/// @title ISonicBridge
/// @notice Comprehensive interface for Sonic Bridge ecosystem contracts
/// @dev Contains all interfaces needed for Sonic <-> Ethereum bridging

/// @notice Interface for Sonic's main Bridge contract on L2
interface ISonicBridge {
    /// @notice Initiates a withdrawal from Sonic to Ethereum
    /// @param uid Unique identifier for the withdrawal
    /// @param token The original token address on Ethereum
    /// @param amount The amount to withdraw
    function withdraw(uint96 uid, address token, uint256 amount) external;

    /// @notice Claims tokens on Sonic from Ethereum deposit
    /// @param id The deposit ID from Ethereum
    /// @param token The token address
    /// @param amount The amount to claim
    /// @param proof The merkle proof for the claim
    function claim(uint256 id, address token, uint256 amount, bytes calldata proof) external;

    /// @notice Emitted when a withdrawal is initiated
    /// @param id The withdrawal ID
    /// @param owner The address initiating the withdrawal
    /// @param token The token being withdrawn
    /// @param amount The amount being withdrawn
    event Withdrawal(uint256 indexed id, address indexed owner, address token, uint256 amount);
}

/// @notice Interface for Sonic's Token Pairs contract
interface ISonicTokenPairs {
    /// @notice Gets the original Ethereum token for a Sonic minted token
    /// @param mintedToken The minted token address on Sonic
    /// @return originalToken The original token address on Ethereum
    function mintedToOriginal(address mintedToken) external view returns (address originalToken);

    /// @notice Gets the Sonic minted token for an Ethereum original token
    /// @param originalToken The original token address on Ethereum
    /// @return mintedToken The minted token address on Sonic
    function originalToMinted(address originalToken) external view returns (address mintedToken);
}

/// @notice Interface for Sonic's State Oracle contract
interface ISonicStateOracle {
    /// @notice Gets the last processed Ethereum block number
    /// @return The last block number processed by the oracle
    function lastBlockNum() external view returns (uint256);

    /// @notice Gets the last state hash
    /// @return The last state hash processed by the oracle
    function lastState() external view returns (bytes32);
}

/// @notice Interface for Ethereum's Token Deposit contract
interface IEthereumTokenDeposit {
    /// @notice Deposits tokens from Ethereum to Sonic
    /// @param uid Unique identifier for the deposit
    /// @param token The token address on Ethereum
    /// @param amount The amount to deposit
    function deposit(uint96 uid, address token, uint256 amount) external;

    /// @notice Claims tokens on Ethereum from Sonic withdrawal
    /// @param id The withdrawal ID from Sonic
    /// @param token The token address
    /// @param amount The amount to claim
    /// @param proof The merkle proof for the claim
    function claim(uint256 id, address token, uint256 amount, bytes calldata proof) external;

    /// @notice Emitted when a deposit is made
    /// @param id The deposit ID
    /// @param owner The address making the deposit
    /// @param token The token being deposited
    /// @param amount The amount being deposited
    event Deposit(uint256 indexed id, address indexed owner, address token, uint256 amount);
}

/// @notice Interface for Ethereum's State Oracle contract
interface IEthereumStateOracle {
    /// @notice Gets the last processed Sonic block number
    /// @return The last block number processed by the oracle
    function lastBlockNum() external view returns (uint256);

    /// @notice Gets the last state hash
    /// @return The last state hash processed by the oracle
    function lastState() external view returns (bytes32);
}

/// @notice Struct for bridge operation details
struct BridgeOperation {
    uint256 id;
    address token;
    uint256 amount;
    address owner;
    uint256 blockNumber;
    bytes32 transactionHash;
    BridgeStatus status;
}

/// @notice Enum for bridge operation status
enum BridgeStatus {
    Initiated,
    Confirmed,
    Claimed,
    Failed
}

/// @notice Interface for comprehensive bridge management
interface ISonicBridgeManager {
    /// @notice Gets bridge operation details
    /// @param operationId The operation ID
    /// @return operation The bridge operation details
    function getBridgeOperation(uint256 operationId) external view returns (BridgeOperation memory operation);

    /// @notice Gets all bridge operations for an address
    /// @param user The user address
    /// @return operations Array of bridge operations
    function getUserBridgeOperations(address user) external view returns (BridgeOperation[] memory operations);

    /// @notice Checks if an operation is ready for claiming
    /// @param operationId The operation ID
    /// @return ready True if ready for claiming
    function isReadyForClaim(uint256 operationId) external view returns (bool ready);
}
