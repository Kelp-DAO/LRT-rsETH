// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IswEXIT {
    function getLastTokenIdCreated() external view returns (uint256);

    function createWithdrawRequest(uint256 amount) external;
    function finalizeWithdrawal(uint256 tokenId) external;
    function processWithdrawals(uint256 lastTokenIdToProcess) external;
}

abstract contract UnstakeSwETH is Initializable {
    IswEXIT public swEXIT;
    IERC20 public swETH;

    event UnstakeSwETHStarted(uint256 tokenId);

    function __initializeSwETH(address _swEXITAddress, address _swETHAddress) internal onlyInitializing {
        swEXIT = IswEXIT(_swEXITAddress);
        swETH = IERC20(_swETHAddress);
    }

    function _unstakeSwEth(uint256 amountToUnstake) internal returns (uint256 tokenId) {
        swETH.approve(address(swEXIT), amountToUnstake);

        // Create withdrawal request
        swEXIT.createWithdrawRequest(amountToUnstake);
        tokenId = swEXIT.getLastTokenIdCreated();
        emit UnstakeSwETHStarted(tokenId);
    }

    function _claimSwEth(uint256 _tokenId) internal {
        swEXIT.finalizeWithdrawal(_tokenId);
    }
}
