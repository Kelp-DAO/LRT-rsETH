// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

interface ILido {
    function submit(address referral) external payable returns (uint256);
    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    function sharesOf(address _account) external view returns (uint256);
}
