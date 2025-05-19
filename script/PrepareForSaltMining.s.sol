// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IZora, Zora} from "../src/zora/Zora.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {LibString} from "solady/utils/LibString.sol";

import "forge-std/Script.sol";

contract MineDeterministicConfig is DeploymentBase {
    function printMintSaltCommand(address deployer, bytes32 initCodeHash, string memory startsWith, address caller) internal pure {
        string memory command = string.concat(
            "cast create2 --starts-with ",
            startsWith,
            " --deployer ",
            LibString.toHexString(deployer),
            " --init-code-hash ",
            LibString.toHexStringNoPrefix(uint256(initCodeHash), 32),
            " --caller ",
            LibString.toHexString(caller)
        );
        console2.log(command);
    }

    function run() public {
        // first we need to get the salt and deterministic config for the deployerAndCaller contract.
        // we pass to its constructor the deployer address, which means that only the deployer can use that contract
        // to deploy and call other contracts.
        address deployer = getDeploymentConfig().admin;

        // now we mine for the salt and expected address for the zora token
        // when creating the zora token, there are no constructor args...the msg.sender is the caller.
        bytes memory tokenCreationCode = abi.encodePacked(type(Zora).creationCode, abi.encode(deployer));

        console2.log("Execute this command to mine the salt for the zora token contract:");
        printMintSaltCommand(IMMUTABLE_CREATE2_FACTORY_ADDRESS, keccak256(tokenCreationCode), "1111111", address(0));
        console2.log("Once this is done, update the deterministicConfig.json file with the new salt and expected address.");

        DeterministicConfig memory deterministicConfig;
        deterministicConfig.creationCode = tokenCreationCode;

        //saveDeterministicConfig(deterministicConfig);
    }
}
