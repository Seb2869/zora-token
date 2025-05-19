// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {DevelopmentCommunityClaim} from "../src/development/DevelopmentCommunityClaim.sol";

import "forge-std/Script.sol";

contract TransferToClaim is DeploymentBase {
    error MismatchedAddresses(address expected, address actual);

    function run() public {
        AddressesConfig memory addressesConfig = getAddressesConfig();

        // start broadcast with the admin address
        vm.startBroadcast();

        Zora zora = Zora(addressesConfig.zoraToken);

        zora.transfer(addressesConfig.developmentCommunityClaim, 100_000_000 * 10 ** 18);

        vm.stopBroadcast();
    }
}
