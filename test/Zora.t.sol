// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Zora} from "../src/zora/Zora.sol";
import {IZora} from "../src/zora/IZora.sol";
import {Test} from "forge-std/Test.sol";
import {IImmutableCreate2Factory} from "../src/deployment/IImmutableCreate2Factory.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ZoraTest is Test {
    address deployer = makeAddr("deployer");

    address constant IMMUTABLE_CREATE2_FACTORY_ADDRESS = 0x0000000000FFe8B47B3e2130213B802212439497;

    function testCanMintInitialDistribution() public {
        address[] memory tos = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tos[0] = makeAddr("to1");
        tos[1] = makeAddr("to2");

        amounts[0] = 10 * 10 ** 18;
        amounts[1] = 50 * 10 ** 18;

        vm.startPrank(deployer);
        Zora zora = new Zora(deployer);
        zora.mintSupply(tos, amounts);

        assertEq(zora.balanceOf(tos[0]), amounts[0]);
        assertEq(zora.balanceOf(tos[1]), amounts[1]);
    }

    function testCannotMintAfterAllSupplyIsMinted() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");

        amounts[0] = 10 * 10 ** 18;

        Zora zora = new Zora(deployer);
        vm.startPrank(deployer);
        zora.mintSupply(tos, amounts);

        vm.expectRevert(IZora.AlreadyMinted.selector);
        zora.mintSupply(new address[](0), new uint256[](0));
    }

    function testCannotMintIfNotDeployer() public {
        address[] memory tos = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tos[0] = makeAddr("to1");
        amounts[0] = 10 * 10 ** 18;

        Zora zora = new Zora(deployer);

        vm.prank(makeAddr("not-deployer"));
        vm.expectRevert(IZora.OnlyMinter.selector);
        zora.mintSupply(tos, amounts);
    }

    function testCanDeterministicallyDeployAtAddress() public {
        // Fork Base network so we have the Immutable Create2 Factory deployed
        vm.createSelectFork("base", 25695331);

        // Get reference to the Immutable Create2 Factory contract
        IImmutableCreate2Factory IMMUTABLE_CREATE2_FACTORY = IImmutableCreate2Factory(IMMUTABLE_CREATE2_FACTORY_ADDRESS);

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

        // Encode the initial mintSupply call for the Zora token

        // Test access control: factory deployer cannot deploy Zora token
        vm.expectRevert(IZora.OnlyMinter.selector);
        IZora(zora).mintSupply(tos, amounts);

        // Deploy Zora token with initial distribution using the authorized deployer
        vm.prank(deployer);
        IZora(zora).mintSupply(tos, amounts);

        // Verify initial token distribution was successful
        assertEq(IERC20(zora).balanceOf(tos[0]), amounts[0]);
        assertEq(IERC20(zora).balanceOf(tos[1]), amounts[1]);
    }

    function saltWithAddressInFirst20Bytes(address addressToMakeSaltWith, uint256 suffix) internal pure returns (bytes32) {
        uint256 shifted = uint256(uint160(address(addressToMakeSaltWith))) << 96;

        // shifted on the left, suffix on the right:

        return bytes32(shifted | suffix);
    }
}
