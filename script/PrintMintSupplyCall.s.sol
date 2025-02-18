// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {IZora} from "../src/zora/IZora.sol";

import "forge-std/Script.sol";

contract DeployToken is DeploymentBase {
    error MismatchedAddresses(address expected, address actual);

    function run() public view {
        (address initializeFrom, bytes memory initializeCall) = getInitializeCall();

        // print out instruction for minting the supply
        console2.log("Execute the following call to mint the supply:");
        console2.log("Multisig:", initializeFrom);
        console2.log("Call:");
        console2.logBytes(initializeCall);
    }
}
