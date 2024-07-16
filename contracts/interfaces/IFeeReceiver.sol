// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IFeeReceiver {
    // Errors
    error InvalidEmptyValue();

    // functions
    function receiveFromNodeDelegator() external payable;
}
