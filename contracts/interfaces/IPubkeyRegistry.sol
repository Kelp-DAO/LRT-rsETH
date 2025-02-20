// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IPubkeyRegistry {
    function hasPubkey(bytes calldata pubkey) external view returns (bool);

    function addPubkey(bytes calldata pubkey) external;

    function addPubkeys(bytes[] calldata pubkeys) external;
}
