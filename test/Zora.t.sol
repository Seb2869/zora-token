// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";
import {IZora} from "../src/zora/IZora.sol";
import {Test} from "forge-std/Test.sol";
import {IImmutableCreate2Factory} from "../src/deployment/IImmutableCreate2Factory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeploymentBase} from "../src/deployment/DeploymentBase.sol";

contract ZoraTest is Test, DeploymentBase {
    address deployer = makeAddr("deployer");

    // Get reference to the Immutable Create2 Factory contract
    IImmutableCreate2Factory IMMUTABLE_CREATE2_FACTORY = IImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);

    function testRevertsIfAdminAddressZero() public {
        vm.expectRevert(IZora.InitializerCannotBeAddressZero.selector);
        new Zora(address(0));
    }

    function testCanMintInitialDistribution() public {
        address[] memory tos = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tos[0] = makeAddr("to1");
        tos[1] = makeAddr("to2");

        amounts[0] = 10 * 10 ** 18;
        amounts[1] = 50 * 10 ** 18;

        vm.startPrank(deployer);
        Zora zora = new Zora(deployer);
        zora.initialize(tos, amounts, "testing");

        assertEq(zora.balanceOf(tos[0]), amounts[0]);
        assertEq(zora.balanceOf(tos[1]), amounts[1]);
    }

    function testCannotInitializeAfterAllSupplyIsMinted() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");

        amounts[0] = 10 * 10 ** 18;

        Zora zora = new Zora(deployer);
        vm.startPrank(deployer);
        zora.initialize(tos, amounts, "testing");

        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        zora.initialize(new address[](0), new uint256[](0), "");
    }

    function testCannotMintIfNotDeployer() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");
        amounts[0] = 10 * 10 ** 18;

        Zora zora = new Zora(deployer);

        vm.prank(makeAddr("not-deployer"));
        vm.expectRevert(IZora.OnlyAdmin.selector);
        zora.initialize(tos, amounts, "");
    }

    function testCanDeterministicallyDeployAtAddress() public {
        // Fork Base network so we have the Immutable Create2 Factory deployed
        vm.createSelectFork("base", 25695331);

        // Create a deterministic salt by combining the factory deployer's address with a suffix
        bytes32 zoraSalt = saltWithAddressInFirst20Bytes(address(0), 3);

        bytes memory zoraCreationCode = abi.encodePacked(type(Zora).creationCode, abi.encode(deployer));
        // Deploy the Zora contract using CREATE2
        address zora = IMMUTABLE_CREATE2_FACTORY.safeCreate2(zoraSalt, zoraCreationCode);

        // Verify the deployed address matches the predicted address
        address expectedAddress = Create2.computeAddress(zoraSalt, keccak256(zoraCreationCode), IMMUTABLE_CREATE2_FACTORY_ADDRESS);

        assertEq(zora, expectedAddress);

        // Set up initial token distribution parameters
        address[] memory tos = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tos[0] = makeAddr("to1");
        tos[1] = makeAddr("to2");
        amounts[0] = 10 * 10 ** 18;
        amounts[1] = 50 * 10 ** 18;

        // Encode the initial initialize call for the Zora token

        // Test access control: factory deployer cannot deploy Zora token
        vm.expectRevert(IZora.OnlyAdmin.selector);
        IZora(zora).initialize(tos, amounts, "uri");

        // Deploy Zora token with initial distribution using the authorized deployer
        vm.prank(deployer);
        IZora(zora).initialize(tos, amounts, "uri");

        // Verify initial token distribution was successful
        assertEq(IERC20(zora).balanceOf(tos[0]), amounts[0]);
        assertEq(IERC20(zora).balanceOf(tos[1]), amounts[1]);
    }

    function saltWithAddressInFirst20Bytes(address addressToMakeSaltWith, uint256 suffix) internal pure returns (bytes32) {
        uint256 shifted = uint256(uint160(address(addressToMakeSaltWith))) << 96;

        // shifted on the left, suffix on the right:

        return bytes32(shifted | suffix);
    }

    function testContractURI() public {
        Zora zora = new Zora(deployer);
        vm.assertEq(zora.contractURI(), "");
        vm.prank(deployer);
        string memory uri = "uri://";
        address[] memory tos = new address[](0);
        uint256[] memory amounts = new uint256[](0);
        zora.initialize(tos, amounts, uri);
        vm.assertEq(zora.contractURI(), "uri://");
    }

    function testDeterministicDeploy() public {
        vm.createSelectFork("base", 26943428);
        DeterministicConfig memory deterministicConfig = getDeterministicConfig(ZORA_TOKEN_CONTRACT_NAME);
        // test that the deployed address is correct
        address deployedAddress = IImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS).safeCreate2(
            deterministicConfig.salt,
            deterministicConfig.creationCode
        );
        assertEq(deployedAddress, deterministicConfig.expectedAddress);

        // test that the configured admin can initialize the token
        (address initializeFrom, bytes memory initializeCall) = getInitializeCall();

        // cannot initialize if not the admin
        (bool success, ) = deployedAddress.call(initializeCall);
        assertEq(success, false);

        // this should succeed as its being called by the admin
        vm.prank(initializeFrom);
        (success, ) = deployedAddress.call(initializeCall);
        assertEq(success, true);

        // cannot reinitialize
        vm.prank(initializeFrom);
        (success, ) = deployedAddress.call(initializeCall);
        assertEq(success, false);
    }
}
