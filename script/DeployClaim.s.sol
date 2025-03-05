// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";

contract DeployClaim is DeploymentBase {
    function run() external {
        vm.startBroadcast();

        DeterministicConfig memory deterministicConfig = getDeterministicConfig();
        ClaimConfig memory claimConfig = getClaimConfig();

        new ZoraTokenCommunityClaim(claimConfig.admin, claimConfig.claimStart, deterministicConfig.expectedAddress);

        vm.stopBroadcast();
    }
}
