// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IZora} from "./IZora.sol";

contract Zora is IZora, ERC20, ERC20Permit, ERC20Votes, Initializable {
    /// @dev Account allowed to mint total supply
    address immutable minter;

    /// @dev Contract URI (only set at initialize)
    string _contractURI;

    constructor(address _minter) ERC20("Zora", "ZORA") ERC20Permit("Zora") {
        minter = _minter;
    }

    /**
     * Mints all the supply to the given addresses.
     * @dev This is not done in the constructor because we want to be able to mine for a deterministic address
     * without changing the creation code of the contract, which would be the case if these values were
     * hardcoded in the constructor.
     * @param tos array of recipient addresses
     * @param amounts array of amounts to mint
     */
    function initialize(address[] calldata tos, uint256[] calldata amounts, string memory contractURI_) public initializer {
        require(tos.length == amounts.length, InvalidInputLengths());
        require(msg.sender == minter, OnlyMinter());
        require(bytes(contractURI_).length > 0, URINeedsToBeSet());

        _contractURI = contractURI_;

        for (uint256 i = 0; i < tos.length; i++) {
            _mint(tos[i], amounts[i]);
        }
    }

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /// @dev Needed to override this OZ function to allow for both ERC20 and ERC20Votes inheritance
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /// @dev Needed to override this OZ function to allow for both ERC20Permit and general OZ inheritance
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
