// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {IZora} from "./IZora.sol";

contract Zora is IZora, ERC20, ERC20Permit, ERC20Votes {
    address immutable deployer;
    bool public mintedAll;

    constructor() ERC20("Zora", "ZORA") ERC20Permit("Zora") {
        deployer = msg.sender;
    }

    /**
     * Mints all the supply to the given addresses.
     * @dev This isn't done in the constructor because we want to be able to mine for a deterministic address
     * without changing the creation code of the contract, which would be the case if these values were
     * hardcoded in the constructor.
     * @param tos array of recipient addresses
     * @param amounts array of amounts to mint
     */
    function mintSupply(address[] calldata tos, uint256[] calldata amounts) public {
        require(msg.sender == deployer, OnlyDeployer());
        require(!mintedAll, AlreadyMinted());
        mintedAll = true;
        require(tos.length == amounts.length, InvalidInputLengths());

        for (uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
