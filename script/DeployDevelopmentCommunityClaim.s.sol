// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {DevelopmentCommunityClaim} from "../src/development/DevelopmentCommunityClaim.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";
import "forge-std/Script.sol";

contract DeployDevelopmentCommunityClaim is DeploymentBase {
    error MismatchedAddresses(address expected, address actual);

    function run() public {
        AddressesConfig memory addressesConfig = getAddressesConfig();

        ClaimConfig memory claimConfig = getClaimConfig(block.chainid);

        // start broadcast with the admin address
        vm.startBroadcast();

        uint256 claimStart = block.timestamp + 1 hours; // 1 hour from now

        addressesConfig.developmentCommunityClaim = address(
            new DevelopmentCommunityClaim(claimConfig.allocationSetter, claimConfig.admin, claimStart, addressesConfig.zoraToken)
        );

        addressesConfig.zoraTokenCommunityClaim = address(
            new ZoraTokenCommunityClaim(claimConfig.allocationSetter, claimConfig.admin, addressesConfig.zoraToken)
        );

        vm.stopBroadcast();

        saveAddressesConfig(addressesConfig);
    }
}
