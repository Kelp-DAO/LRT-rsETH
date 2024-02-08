// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ILayerZeroReceiver } from "../interfaces/ILayerZeroReceiver.sol";

/// @title Cross chain rate receiver. By witherblock reference: https://github.com/witherblock/gyarados
/// @notice Receives a rate from a provider contract on a different chain than the one this contract is deployed on
/// @dev Powered using LayerZero
abstract contract CrossChainRateReceiver is ILayerZeroReceiver, Ownable {
    /// @notice Last rate updated on the receiver
    uint256 public rate;

    /// @notice Last time rate was updated
    uint256 public lastUpdated;

    /// @notice Source chainId
    uint16 public srcChainId;

    /// @notice Rate Provider address
    address public rateProvider;

    /// @notice LayerZero endpoint address
    address public layerZeroEndpoint;

    /// @notice Information of which token and base token rate is being provided
    RateInfo public rateInfo;

    struct RateInfo {
        string tokenSymbol;
        string baseTokenSymbol;
    }

    /// @notice Emitted when rate is updated
    /// @param newRate the rate that was updated
    event RateUpdated(uint256 newRate);

    /// @notice Emitted when RateProvider is updated
    /// @param newRateProvider the RateProvider address that was updated
    event RateProviderUpdated(address newRateProvider);

    /// @notice Emitted when the source chainId is updated
    /// @param newSrcChainId the source chainId that was updated
    event SrcChainIdUpdated(uint16 newSrcChainId);

    /// @notice Emitted when LayerZero Endpoint is updated
    /// @param newLayerZeroEndpoint the LayerZero Endpoint address that was updated
    event LayerZeroEndpointUpdated(address newLayerZeroEndpoint);

    /// @notice Updates the LayerZero Endpoint address
    /// @dev Can only be called by owner
    /// @param _layerZeroEndpoint the new layer zero endpoint address
    function updateLayerZeroEndpoint(address _layerZeroEndpoint) external onlyOwner {
        layerZeroEndpoint = _layerZeroEndpoint;

        emit LayerZeroEndpointUpdated(_layerZeroEndpoint);
    }

    /// @notice Updates the RateProvider address
    /// @dev Can only be called by owner
    /// @param _rateProvider the new rate provider address
    function updateRateProvider(address _rateProvider) external onlyOwner {
        rateProvider = _rateProvider;

        emit RateProviderUpdated(_rateProvider);
    }

    /// @notice Updates the source chainId
    /// @dev Can only be called by owner
    /// @param _srcChainId the source chainId
    function updateSrcChainId(uint16 _srcChainId) external onlyOwner {
        srcChainId = _srcChainId;

        emit SrcChainIdUpdated(_srcChainId);
    }

    /// @notice LayerZero receive function which is called via send from a different chain
    /// @param _srcChainId The source chainId
    /// @param _srcAddress The source address
    /// @param _payload The payload
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64, bytes calldata _payload) external {
        require(msg.sender == layerZeroEndpoint, "Sender should be lz endpoint");

        address srcAddress;
        assembly {
            srcAddress := mload(add(_srcAddress, 20))
        }

        require(_srcChainId == srcChainId, "Src chainId must be correct");
        require(srcAddress == rateProvider, "Src address must be provider");

        uint256 _rate = abi.decode(_payload, (uint256));

        rate = _rate;

        lastUpdated = block.timestamp;

        emit RateUpdated(_rate);
    }

    /// @notice Gets the last stored rate in the contract
    function getRate() external view returns (uint256) {
        return rate;
    }
}
