// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZora {
    /// @notice Used once durign deploy to mint and allocate the initial and total supply of the ERC20
    /// @param tos Addresses to allocate tokens to by the deployer
    /// @param amounts Amounts of tokens to allocate alongside the tos address array
    function mintSupply(address[] calldata tos, uint256[] calldata amounts) external;

    /// @dev Parameter that the NFT has already been minted and cannot be minted again
    error AlreadyMinted();
    /// @dev Invalid input lengths when the tos and amounts array lengths do not match
    error InvalidInputLengths();
    /// @dev Error when any user other than the deployer attempts to mint the initial and final supply.
    error OnlyDeployer();
}