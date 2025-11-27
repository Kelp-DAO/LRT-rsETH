// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { CrossChainRateReceiver } from "contracts/cross-chain/CrossChainRateReceiver.sol";

/// @title agETH cross chain rate receiver
/// @notice Receives the agETH rate from a provider contract on a different chain than the one this contract is deployed
/// on
contract AGETHRateReceiver is CrossChainRateReceiver {
    constructor(uint16 _srcChainId, address _rateProvider, address _layerZeroEndpoint) {
        rateInfo = RateInfo({ tokenSymbol: "agETH", baseTokenSymbol: "ETH" });
        srcChainId = _srcChainId;
        rateProvider = _rateProvider;
        layerZeroEndpoint = _layerZeroEndpoint;
    }
}
