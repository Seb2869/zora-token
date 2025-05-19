// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {DevelopmentCommunityClaim} from "../src/development/DevelopmentCommunityClaim.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";
import "forge-std/Script.sol";

contract DeployDevelopmentContracts is DeploymentBase {
    error MismatchedAddresses(address expected, address actual);

    function run() public {
        AddressesConfig memory addressesConfig = getAddressesConfig();

        ClaimConfig memory claimConfig = getClaimConfig(block.chainid);

        // start broadcast with the admin address
        vm.startBroadcast();

        Zora zora = new Zora(claimConfig.allocationSetter);

        // deploy the zora token contract and call the initialize function
        // can only be called by the deployer
        addressesConfig.zoraToken = address(zora);

        uint256 claimStart = block.timestamp + 1 minutes; // 1 minute from now

        addressesConfig.developmentCommunityClaim = address(
            new DevelopmentCommunityClaim(claimConfig.allocationSetter, claimConfig.admin, claimStart, addressesConfig.zoraToken)
        );

        addressesConfig.zoraTokenCommunityClaim = address(
            new ZoraTokenCommunityClaim(claimConfig.allocationSetter, claimConfig.admin, addressesConfig.zoraToken)
        );

        address[] memory users = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        // give half to the allocation setter
        users[0] = claimConfig.allocationSetter;
        amounts[0] = 5_000_000_000 * 1e18;
        // give half to the admin
        users[1] = claimConfig.admin;
        amounts[1] = 5_000_000_000 * 1e18;

        zora.initialize(users, amounts, "https://www.theme.wtf/assets/metadata.json");

        vm.stopBroadcast();

        saveAddressesConfig(addressesConfig);
    }
}
