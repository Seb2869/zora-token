// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";

contract DeployClaim is DeploymentBase {
    function run() external {
        vm.startBroadcast();

        AddressesConfig memory addressesConfig = getAddressesConfig();

        DeterministicConfig memory claimDeterministicConfig = getDeterministicConfig(ZORA_TOKEN_COMMUNITY_CLAIM_BASE_CONTRACT_NAME);

        addressesConfig.zoraTokenCommunityClaim = getImmutableCreate2Factory().safeCreate2(
            claimDeterministicConfig.salt,
            claimDeterministicConfig.creationCode
        );

        require(addressesConfig.zoraTokenCommunityClaim == claimDeterministicConfig.expectedAddress, "Mismatched addresses");

        ZoraTokenCommunityClaim claim = ZoraTokenCommunityClaim(addressesConfig.zoraTokenCommunityClaim);

        ClaimConfig memory claimConfig = getClaimConfig(block.chainid);

        require(claim.admin() == claimConfig.admin, "Mismatched admin");
        require(claim.allocationSetter() == claimConfig.allocationSetter, "Mismatched allocation setter");

        saveAddressesConfig(addressesConfig);

        vm.stopBroadcast();
    }
}
