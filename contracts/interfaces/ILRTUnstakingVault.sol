// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IStrategy } from "contracts/external/eigenlayer/interfaces/IStrategy.sol";
import { IEigenDelegationManager } from "contracts/external/eigenlayer/interfaces/IEigenDelegationManager.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILRTUnstakingVault {
    error CallerNotLRTNodeDelegator();
    error EthTransferFailed();
    error CallerNotLRTWithdrawalManager();

    event EthReceived(address sender, uint256 amount);

    // functions
    function sharesUnstaking(address asset) external view returns (uint256);

    function getAssetsUnstaking(address asset) external view returns (uint256);

    function balanceOf(address asset) external view returns (uint256);

    function addSharesUnstaking(address asset, uint256 amount) external;

    function reduceSharesUnstaking(address asset, uint256 amount) external;

    function redeem(address asset, uint256 amount) external;

    // receive functions
    function receiveFromLRTDepositPool() external payable;
    function receiveFromNodeDelegator() external payable;
}
