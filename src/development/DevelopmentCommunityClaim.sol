// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IZoraTokenCommunityClaim} from "../claim/IZoraTokenCommunityClaim.sol";
import {ZoraTokenCommunityClaim} from "../claim/ZoraTokenCommunityClaim.sol";

/// Similar to ZoraTokenCommunityClaim but adds useful functions for development purposes:
/// Allows setting the claim start time even after claim has started
/// Allows resetting if a user has claimed; allowing a user to claim multiple times
/// Allowing setting of allocations regardless of whether the claim has started or setup is complete
contract DevelopmentCommunityClaim is ZoraTokenCommunityClaim {
    // Compact allocations stored as uint96 (token count, will be multiplied by 1e18)
    constructor(address _allocationSetter, address _admin, uint256 _claimStart, address _token) ZoraTokenCommunityClaim(_allocationSetter, _admin, _token) {
        claimStart = _claimStart;
    }

    // override - allows to set allocations even after claim has started
    function _checkCanSetAllocations(address _sender) internal view override {
        require(_sender == allocationSetter, OnlyAllocationSetter());
    }

    function _checkCanClaim() internal view override {
        // override - allows to claim even before claim has started
    }

    // special function to set the claim start time only available on the dev contract
    function _checkCanUpdateClaimStart(uint256) internal view override {
        require(msg.sender == admin, OnlyAdmin());
        // override - allows to update claim start even after claim has started
    }

    event ResetHasClaimed(address[] users);

    function resetHasClaimed(address[] calldata _users) external {
        require(msg.sender == allocationSetter, OnlyAllocationSetter());
        for (uint256 i = 0; i < _users.length; i++) {
            accountClaims[_users[i]].claimed = false;
        }

        emit ResetHasClaimed(_users);
    }
}
