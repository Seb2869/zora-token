// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Provides tracking nonces for addresses. Nonces can be in any order and just need to be unique.
 */
abstract contract UnorderedNonces {
    /**
     * @dev The nonce used for an `account` is not the expected current nonce.
     */
    error InvalidAccountNonce(address account, bytes32 currentNonce);

    /// @custom:storage-location erc7201:unorderedNonces.storage.UnorderedNoncesStorage
    mapping(address account => mapping(bytes32 => bool)) nonces;

    /**
     * @dev Returns whether a nonce has been used for an address.
     */
    function nonceUsed(address owner, bytes32 nonce) public view virtual returns (bool) {
        return nonces[owner][nonce];
    }

    /**
     * @dev Same as {_useNonce} but checking that `nonce` passed in is valid.
     */
    function _useCheckedNonce(address owner, bytes32 nonce) internal virtual {
        if (nonces[owner][nonce]) {
            revert InvalidAccountNonce(owner, nonce);
        }
        nonces[owner][nonce] = true;
    }
}
