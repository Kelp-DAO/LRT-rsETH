// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface ILidoWithdrawalQueue {
    function requestWithdrawals(
        uint256[] calldata _amounts,
        address _owner
    )
        external
        returns (uint256[] memory requestIds);

    ///  Usage: findCheckpointHints(_requestIds, 1, getLastCheckpointIndex())
    function findCheckpointHints(
        uint256[] calldata _requestIds,
        uint256 _firstIndex,
        uint256 _lastIndex
    )
        external
        view
        returns (uint256[] memory hintIds);

    function getLastCheckpointIndex() external view returns (uint256);

    function claimWithdrawalsTo(
        uint256[] calldata _requestIds,
        uint256[] calldata _hints,
        address _recipient
    )
        external;
    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getLastRequestId() external view returns (uint256);
}

abstract contract UnstakeStETH is Initializable {
    ILidoWithdrawalQueue public withdrawalQueue;
    IERC20 public stETH;

    event UnstakeStETHStarted(uint256 tokenId);

    function __initializeStETH(address _withdrawalQueue, address _stETHAddress) internal onlyInitializing {
        withdrawalQueue = ILidoWithdrawalQueue(_withdrawalQueue);
        stETH = IERC20(_stETHAddress);
    }

    function _unstakeStEth(uint256 amountToUnstake) internal {
        stETH.approve(address(withdrawalQueue), amountToUnstake);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amountToUnstake;

        uint256[] memory requestIds = withdrawalQueue.requestWithdrawals(amounts, address(this));

        emit UnstakeStETHStarted(requestIds[0]);
    }

    function _claimStEth(uint256 _requestId, uint256 _hint) internal {
        uint256[] memory requestIds = new uint256[](1);
        uint256[] memory hints = new uint256[](1);
        requestIds[0] = _requestId;
        hints[0] = _hint;
        withdrawalQueue.claimWithdrawalsTo(requestIds, hints, address(this));
    }
}
