// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Zora} from "../../src/zora/Zora.sol";
import {DevelopmentCommunityClaim} from "../../src/development/DevelopmentCommunityClaim.sol";
import {IZoraTokenCommunityClaim} from "../../src/claim/IZoraTokenCommunityClaim.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract DevelopmentCommunityClaimTest is Test {
    address admin;
    address allocationSetter;
    uint256 allocationSetterPrivateKey;
    address originalTokenHolder;
    Zora token;
    DevelopmentCommunityClaim claim;
    uint256 claimStart;

    function setUp() public {
        admin = makeAddr("admin");
        (allocationSetter, allocationSetterPrivateKey) = makeAddrAndKey("allocationSetter");
        originalTokenHolder = makeAddr("originalTokenHolder");
        token = new Zora(admin);
        claimStart = block.timestamp + 1 hours;
        claim = new DevelopmentCommunityClaim(allocationSetter, admin, claimStart, address(token));

        // Fund claim contract with tokens
        vm.startPrank(admin);
        address[] memory claimAddress = new address[](1);
        uint256[] memory claimAmount = new uint256[](1);
        claimAddress[0] = originalTokenHolder;
        claimAmount[0] = 1_000_000_000 * 1e18;
        token.initialize(claimAddress, claimAmount, "testing");
        vm.stopPrank();

        vm.prank(originalTokenHolder);
        token.transfer(address(claim), 1_000_000_000 * 1e18);
    }

    function toCompactAllocations(address[] memory accounts, uint96[] memory amounts) private pure returns (bytes32[] memory) {
        bytes32[] memory packedData = new bytes32[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            // Pack address into lower 160 bits, amount into upper 96 bits
            // This matches how the contract unpacks: address from first 160 bits, amount from bits shifted right by 160
            packedData[i] = bytes32(uint256(uint160(accounts[i])) | (uint256(amounts[i]) << 160));
        }
        return packedData;
    }

    function testSetAllocations() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        address[] memory accounts = new address[](2);
        uint96[] memory amounts = new uint96[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        assertEq(claim.allocations(user1), 100 * 1e18);
        assertEq(claim.allocations(user2), 200 * 1e18);
    }

    function testCannotSetAllocationsIfNotAllocationSetter() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(makeAddr("not-allocation-setter"));
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAllocationSetter.selector);
        claim.setAllocations(compactAllocations);
    }

    function testCanSetAllocationsAfterClaimStart() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.warp(claimStart + 1);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);
    }

    function testCanSetAllocationsIfSetupCompleted() public {
        address[] memory accounts = new address[](0);
        uint96[] memory amounts = new uint96[](0);

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);
    }

    function testCannotCompleteSetupIfNotAdmin() public {
        vm.prank(makeAddr("not-admin"));
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAdmin.selector);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);
    }

    function testCanClaimBeforeStart() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(user1);
        claim.claim(user1);
    }

    function testCanClaimBeforeSetupComplete() public {
        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        vm.prank(user1);
        claim.claim(user1);
    }

    function _getSetAllocationsDigest(bytes32[] memory packedData, bytes32 nonce) private view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(keccak256("SetAllocations(bytes32[] packedData,bytes32 nonce)"), keccak256(abi.encodePacked(packedData)), nonce)
        );

        return keccak256(abi.encodePacked("\x19\x01", claim.getDomainSeparator(), structHash));
    }

    function testCanSetAllocationsWithSignatureAfterSetupComplete() public {
        vm.prank(allocationSetter);

        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);
        bytes32 nonce = keccak256("test-nonce");

        // Create signature
        bytes32 digest = _getSetAllocationsDigest(compactAllocations, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(allocationSetterPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Complete setup
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // Attempt to set allocations should succeed
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);
    }
}
