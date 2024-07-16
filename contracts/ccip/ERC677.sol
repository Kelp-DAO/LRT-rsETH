// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

interface IERC677Receiver {
    function onTokenTransfer(address sender, uint256 amount, bytes calldata data) external;
}

interface IERC677 {
    event Transfer(address indexed from, address indexed to, uint256 value, bytes data);

    /// @notice Transfer tokens from `msg.sender` to another address and then call `onTransferReceived` on receiver
    /// @param to The address which you want to transfer to
    /// @param amount The amount of tokens to be transferred
    /// @param data bytes Additional data with no specified format, sent in call to `to`
    /// @return true unless throwing
    function transferAndCall(address to, uint256 amount, bytes memory data) external returns (bool);
}

contract ERC677 is IERC677, ERC20 {
    using Address for address;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) { }

    /// @inheritdoc IERC677
    function transferAndCall(address to, uint256 amount, bytes memory data) public returns (bool success) {
        super.transfer(to, amount);
        emit Transfer(msg.sender, to, amount, data);
        if (to.isContract()) {
            IERC677Receiver(to).onTokenTransfer(msg.sender, amount, data);
        }
        return true;
    }
}
