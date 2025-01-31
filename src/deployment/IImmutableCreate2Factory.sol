// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Extracted interface of ImmutableCreate2Factory.sol, located at https://raw.githubusercontent.com/0age/metamorphic/master/contracts/ImmutableCreate2Factory.sol

interface IImmutableCreate2Factory {
    /**
     * @dev Create a contract using CREATE2 by submitting a given salt or nonce
     * along with the initialization code for the contract. Note that the first 20
     * bytes of the salt must match those of the calling address, which prevents
     * contract creation events from being submitted by unintended parties.
     * @param salt bytes32 The nonce that will be passed into the CREATE2 call.
     * @param initializationCode bytes The initialization code that will be passed
     * into the CREATE2 call.
     * @return deploymentAddress Address of the contract that will be created, or the null address
     * if a contract already exists at that address.
     */
    function safeCreate2(bytes32 salt, bytes calldata initializationCode) external payable returns (address deploymentAddress);
}
