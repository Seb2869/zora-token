// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";
import {LibString} from "solady/utils/LibString.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";

import "forge-std/Script.sol";

contract MineDeterministicConfig is DeploymentBase {
    function printMintSaltCommand(address deployer, bytes32 initCodeHash, string memory startsWith, address caller) internal pure {
        string memory command = string.concat(
            "cargo run --release -- --starts-with ",
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
        ClaimConfig memory claimConfig = getClaimConfig(block.chainid);

        DeterministicConfig memory tokenDeterministicConfig = getDeterministicConfig(ZORA_TOKEN_CONTRACT_NAME);

        // now we mine for the salt and expected address for the zora token
        // when creating the zora token, there are no constructor args...the msg.sender is the caller.
        bytes memory tokenCreationCode = abi.encodePacked(
            type(ZoraTokenCommunityClaim).creationCode,
            abi.encode(claimConfig.allocationSetter, claimConfig.admin, tokenDeterministicConfig.expectedAddress)
        );

        console2.log("Execute this command to mine the salt for the zora token contract:");
        printMintSaltCommand(IMMUTABLE_CREATE2_FACTORY_ADDRESS, keccak256(tokenCreationCode), "0000000000", address(0));

        DeterministicConfig memory deterministicConfig;
        deterministicConfig.creationCode = tokenCreationCode;

        saveDeterministicConfig(deterministicConfig, ZORA_TOKEN_COMMUNITY_CLAIM_BASE_CONTRACT_NAME);
    }
}
