// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Zora} from "../src/zora/Zora.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";
import {IZoraTokenCommunityClaim} from "../src/claim/IZoraTokenCommunityClaim.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IMultiOwnable {
    function isValidSignature(bytes32 _messageHash, bytes memory _signature) external view returns (bytes4 magicValue);
}

contract MockSmartWallet is IMultiOwnable {
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e; // bytes4(keccak256("isValidSignature(bytes32,bytes)"))
    mapping(address => bool) public isOwner;

    constructor(address _owner) {
        isOwner[_owner] = true;
    }

    function addOwner(address _owner) external {
        isOwner[_owner] = true;
    }

    function isValidSignature(bytes32 _messageHash, bytes memory _signature) public view returns (bytes4 magicValue) {
        address signatory = ECDSA.recover(_messageHash, _signature);

        if (isOwner[signatory]) {
            return MAGIC_VALUE;
        } else {
            return bytes4(0);
        }
    }

    receive() external payable {}
}

contract ZoraTokenCommunityClaimTest is Test {
    address deployer;
    Zora token;
    ZoraTokenCommunityClaim claim;
    uint256 claimStart;

    function setUp() public {
        deployer = makeAddr("deployer");
        token = new Zora(deployer);
        claimStart = block.timestamp + 1 hours;
        claim = new ZoraTokenCommunityClaim(deployer, claimStart, address(token));

        // Fund claim contract with tokens
        vm.startPrank(deployer);
        address[] memory claimAddress = new address[](1);
        uint256[] memory claimAmount = new uint256[](1);
        claimAddress[0] = address(claim);
        claimAmount[0] = 1000 * 1e18;
        token.initialize(claimAddress, claimAmount, "testing");
        vm.stopPrank();
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

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        assertEq(claim.allocations(user1), 100 * 1e18);
        assertEq(claim.allocations(user2), 200 * 1e18);
    }

    function testCannotSetAllocationsIfNotAdmin() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(makeAddr("not-admin"));
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAdmin.selector);
        claim.setAllocations(compactAllocations);
    }

    function testCannotSetAllocationsAfterClaimStart() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.warp(claimStart + 1);

        vm.prank(deployer);
        vm.expectRevert(IZoraTokenCommunityClaim.ClaimOpened.selector);
        claim.setAllocations(compactAllocations);
    }

    function testBasicClaim() public {
        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Claim
        vm.prank(user1);
        claim.claim(user1);

        // Verify
        assertEq(token.balanceOf(user1), amount);
        assertEq(claim.allocations(user1), amount);
        assertEq(claim.hasClaimed(user1), true);
    }

    function testCannotClaimBeforeStart() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        vm.prank(user1);
        vm.expectRevert(IZoraTokenCommunityClaim.ClaimNotOpen.selector);
        claim.claim(user1);
    }

    function _getSignatureDigest(address user, address claimTo, uint256 deadline) private view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(keccak256("ClaimWithSignature(address user,address claimTo,uint256 deadline)"), user, claimTo, deadline));

        return keccak256(abi.encodePacked("\x19\x01", claim.getDomainSeparator(), structHash));
    }

    function testSignatureClaim() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        address recipient = makeAddr("recipient");
        uint96 amount = 100 * 1e18;

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = signer;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Create signature
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Claim with signature
        claim.claimWithSignature(signer, recipient, deadline, signature);

        // Verify
        assertEq(token.balanceOf(recipient), amount);
        assertEq(claim.allocations(signer), amount);
        assertEq(claim.hasClaimed(signer), true);
    }

    function testCannotReuseSignature() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        address recipient = makeAddr("recipient");
        uint96 amount = 100 * 1e18;

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = signer;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // First claim should succeed
        claim.claimWithSignature(signer, recipient, deadline, signature);

        // Second claim should fail due to no allocation
        vm.expectRevert(IZoraTokenCommunityClaim.AlreadyClaimed.selector);
        claim.claimWithSignature(signer, recipient, deadline, signature);
    }

    function testCannotClaimWithExpiredSignature() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        address recipient = makeAddr("recipient");

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = signer;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        uint256 deadline = block.timestamp - 1;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IZoraTokenCommunityClaim.SignatureExpired.selector);
        claim.claimWithSignature(signer, recipient, deadline, signature);
    }

    function testCannotClaimWithInvalidSignature() public {
        uint256 wrongPrivateKey = 0x5678;
        address signer = makeAddr("signer"); // Different from the key we'll sign with
        address recipient = makeAddr("recipient");

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = signer;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IZoraTokenCommunityClaim.InvalidSignature.selector);
        claim.claimWithSignature(signer, recipient, deadline, signature);
    }

    function testSmartWalletClaim() public {
        uint256 ownerPrivateKey = 0x1234;
        address owner = vm.addr(ownerPrivateKey);

        // Deploy mock smart wallet
        MockSmartWallet smartWallet = new MockSmartWallet(owner);
        address recipient = makeAddr("recipient");
        uint96 amount = 100 * 1e18;

        // Set allocation for the smart wallet
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = address(smartWallet);
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Create signature
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(address(smartWallet), recipient, deadline);

        // Owner signs the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Claim with signature
        claim.claimWithSignature(address(smartWallet), recipient, deadline, signature);

        // Verify
        assertEq(token.balanceOf(recipient), amount);
        assertEq(claim.allocations(address(smartWallet)), amount);
        assertEq(claim.hasClaimed(address(smartWallet)), true);
    }

    function testSmartWalletClaimWithInvalidSigner() public {
        uint256 ownerPrivateKey = 0x1234;
        address owner = vm.addr(ownerPrivateKey);
        uint256 nonOwnerPrivateKey = 0x5678;

        // Deploy mock smart wallet
        MockSmartWallet smartWallet = new MockSmartWallet(owner);
        address recipient = makeAddr("recipient");
        uint96 amount = 100 * 1e18;

        // Set allocation for the smart wallet
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = address(smartWallet);
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(deployer);
        claim.setAllocations(compactAllocations);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Create signature with non-owner
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(address(smartWallet), recipient, deadline);

        // Non-owner signs the message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonOwnerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to claim with invalid signature should fail
        vm.expectRevert(IZoraTokenCommunityClaim.InvalidSignature.selector);
        claim.claimWithSignature(address(smartWallet), recipient, deadline, signature);
    }
}
