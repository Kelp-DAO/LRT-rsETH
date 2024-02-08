// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

contract MockPriceAggregator {
    uint256 public price;

    constructor() {
        price = 1 ether;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, int256(price), 0, 0, 0);
    }

    function setPrice(uint256 price_) external {
        price = price_;
    }
}
