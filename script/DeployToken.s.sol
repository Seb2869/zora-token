// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {IZora} from "../src/zora/IZora.sol";

import "forge-std/Script.sol";

contract DeployToken is DeploymentBase {
    error MismatchedAddresses(address expected, address actual);

    function run() public {
        DeterministicConfig memory deterministicConfig = getDeterministicConfig();

        vm.startBroadcast();
        // deploy the zora token contract and call the initialize function
        // can only be called by the deployer
        address zoraToken = getImmutableCreate2Factory().safeCreate2(deterministicConfig.salt, deterministicConfig.creationCode);

        require(zoraToken == deterministicConfig.expectedAddress, MismatchedAddresses(deterministicConfig.expectedAddress, zoraToken));

        vm.stopBroadcast();

        (address initializeFrom, bytes memory initializeCall) = getInitializeCall();

        // print out instruction for minting the supply
        console2.log("Execute the following call to mint the supply:");
        console2.log("Multisig:", initializeFrom);
        console2.log("Call:");
        console2.logBytes(initializeCall);
    }
}
