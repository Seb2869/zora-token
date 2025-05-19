// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";

contract DeployClaim is DeploymentBase {
    function run() external {
        AddressesConfig memory addressesConfig = getAddressesConfig();

        ClaimConfig memory claimConfig = getClaimConfig(block.chainid);

        // start broadcast with the admin address
        vm.startBroadcast();

        addressesConfig.zoraTokenCommunityClaim = address(
            new ZoraTokenCommunityClaim(claimConfig.allocationSetter, claimConfig.admin, addressesConfig.zoraToken)
        );

        vm.stopBroadcast();

        saveAddressesConfig(addressesConfig);
    }
}
