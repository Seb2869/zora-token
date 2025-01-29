// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZora {
    function mintSupply(address[] calldata tos, uint256[] calldata amounts) external;
    error AlreadyMinted();
    error InvalidInputLengths();
    error OnlyDeployer();
}