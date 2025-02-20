// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title ChainlinkOracleForRSETHPoolCollateral Contract
/// @notice Wrapper contract for Chainlink oracles
contract ChainlinkOracleForRSETHPoolCollateral {
    address public immutable oracle;

    error StalePrice();
    error IncompleteRound();
    error InvalidPrice();

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function getRate() public view returns (uint256) {
        (uint80 roundID, int256 ethPrice,, uint256 timestamp, uint80 answeredInRound) =
            AggregatorV3Interface(oracle).latestRoundData();

        if (answeredInRound < roundID) revert StalePrice();
        if (timestamp == 0) revert IncompleteRound();
        if (ethPrice <= 0) revert InvalidPrice();

        uint256 normalizedPrice = uint256(ethPrice) * 1e18 / 10 ** uint256(AggregatorV3Interface(oracle).decimals());

        return normalizedPrice;
    }

    function rate() external view returns (uint256) {
        return getRate();
    }
}
