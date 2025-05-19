// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IImmutableCreate2Factory} from "./IImmutableCreate2Factory.sol";
import {IZora} from "../zora/IZora.sol";

contract DeploymentBase is Script {
    using stdJson for string;

    address constant IMMUTABLE_CREATE2_FACTORY_ADDRESS = 0x0000000000FFe8B47B3e2130213B802212439497;

    string constant ZORA_TOKEN_CONTRACT_NAME = "token";
    string constant ZORA_TOKEN_COMMUNITY_CLAIM_BASE_CONTRACT_NAME = "claimBase";

    // Struct to match the JSON structure
    struct InitialMint {
        address addr;
        string amount;
        string name;
    }

    struct DeploymentConfig {
        address admin;
        string contractURI;
        InitialMint[] initialMints;
    }

    struct DeterministicConfig {
        bytes32 salt;
        address expectedAddress;
        bytes creationCode;
    }

    struct ClaimConfig {
        address admin;
        address allocationSetter;
    }

    struct AddressesConfig {
        address zoraToken;
        address zoraTokenCommunityClaim;
        address developmentCommunityClaim;
    }

    function deploymentConfigPath() internal pure returns (string memory) {
        return "script/config/deploymentConfig.json";
    }

    function deterministicConfigPath(string memory contractName) internal pure returns (string memory) {
        return string.concat("script/config/deterministic/", contractName, ".json");
    }

    function claimConfigPath(uint256 chainId) internal pure returns (string memory) {
        return string.concat("script/config/claim/", vm.toString(chainId), ".json");
    }

    function addressesConfigPath(uint256 chainId) internal pure returns (string memory) {
        return string.concat("addresses/", vm.toString(chainId), ".json");
    }

    function getDeploymentConfig() internal view returns (DeploymentConfig memory) {
        string memory path = deploymentConfigPath();
        string memory json = vm.readFile(path);

        // Parse the entire JSON into our struct
        bytes memory data = vm.parseJson(json);
        return abi.decode(data, (DeploymentConfig));
    }

    function getClaimConfig(uint256 chainId) internal view returns (ClaimConfig memory) {
        string memory path = claimConfigPath(chainId);
        string memory json = vm.readFile(path);

        bytes memory data = vm.parseJson(json);
        return abi.decode(data, (ClaimConfig));
    }

    function saveDeterministicConfig(DeterministicConfig memory deterministicConfig, string memory contractName) internal {
        string memory objectKey = "config";

        vm.serializeBytes32(objectKey, "salt", deterministicConfig.salt);
        vm.serializeBytes(objectKey, "creationCode", deterministicConfig.creationCode);
        string memory result = vm.serializeAddress(objectKey, "expectedAddress", deterministicConfig.expectedAddress);

        vm.writeJson(result, deterministicConfigPath(contractName));
    }

    /// @notice Return a prefixed key for reading with a ".".
    /// @param key key to prefix
    /// @return prefixed key
    function getKeyPrefix(string memory key) internal pure returns (string memory) {
        return string.concat(".", key);
    }

    function readAddressOrDefaultToZero(string memory json, string memory key) internal view returns (address addr) {
        string memory keyPrefix = getKeyPrefix(key);

        if (vm.keyExists(json, keyPrefix)) {
            addr = json.readAddress(keyPrefix);
        } else {
            addr = address(0);
        }
    }

    function getAddressesConfig() internal view returns (AddressesConfig memory config) {
        string memory json = vm.readFile(addressesConfigPath(block.chainid));
        config.zoraToken = readAddressOrDefaultToZero(json, "ZORA_TOKEN");
        config.zoraTokenCommunityClaim = readAddressOrDefaultToZero(json, "ZORA_TOKEN_COMMUNITY_CLAIM");
        config.developmentCommunityClaim = readAddressOrDefaultToZero(json, "DEVELOPMENT_COMMUNITY_CLAIM");
    }

    function saveAddressesConfig(AddressesConfig memory config) internal {
        string memory objectKey = "config";

        vm.serializeAddress(objectKey, "ZORA_TOKEN", config.zoraToken);
        vm.serializeAddress(objectKey, "ZORA_TOKEN_COMMUNITY_CLAIM", config.zoraTokenCommunityClaim);
        string memory result = vm.serializeAddress(objectKey, "DEVELOPMENT_COMMUNITY_CLAIM", config.developmentCommunityClaim);
        vm.writeJson(result, addressesConfigPath(block.chainid));
    }

    function getDeterministicConfig(string memory contractName) internal view returns (DeterministicConfig memory config) {
        string memory path = deterministicConfigPath(contractName);
        string memory json = vm.readFile(path);

        config.salt = json.readBytes32(".salt");
        config.creationCode = json.readBytes(".creationCode");
        config.expectedAddress = json.readAddress(".expectedAddress");
    }

    function getImmutableCreate2Factory() internal pure returns (IImmutableCreate2Factory) {
        return IImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);
    }

    function parseConfigAmount(string memory amountStr) internal pure returns (uint256) {
        bytes memory amountBytes = bytes(amountStr);
        bytes memory cleanBytes = new bytes(bytes(amountStr).length);
        uint256 j = 0;
        // remove underscores:
        for (uint256 k = 0; k < amountBytes.length; k++) {
            if (amountBytes[k] != "_") {
                cleanBytes[j] = amountBytes[k];
                j++;
            }
        }
        // Create new string with exact length
        bytes memory finalBytes = new bytes(j);
        for (uint256 k = 0; k < j; k++) {
            finalBytes[k] = cleanBytes[k];
        }
        return vm.parseUint(string(finalBytes)) * 10 ** 18;
    }

    function getInitialMints() internal view returns (address[] memory tos, uint256[] memory amounts) {
        DeploymentConfig memory config = getDeploymentConfig();

        tos = new address[](config.initialMints.length);
        amounts = new uint256[](config.initialMints.length);

        for (uint256 i = 0; i < config.initialMints.length; i++) {
            tos[i] = config.initialMints[i].addr;
            amounts[i] = parseConfigAmount(config.initialMints[i].amount);
        }
    }

    function getInitializeCall() internal view returns (address from, bytes memory call) {
        DeploymentConfig memory config = getDeploymentConfig();

        from = config.admin;

        (address[] memory tos, uint256[] memory amounts) = getInitialMints();
        call = abi.encodeWithSelector(IZora.initialize.selector, tos, amounts, config.contractURI);
    }
}
