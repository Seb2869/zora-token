// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Zora} from "../src/zora/Zora.sol";
import {ZoraTokenCommunityClaim} from "../src/claim/ZoraTokenCommunityClaim.sol";
import {IZoraTokenCommunityClaim} from "../src/claim/IZoraTokenCommunityClaim.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {UnorderedNonces} from "../src/utils/UnorderedNonces.sol";

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
    address admin;
    address allocationSetter;
    uint256 allocationSetterPrivateKey;
    address originalTokenHolder;
    Zora token;
    ZoraTokenCommunityClaim claim;
    uint256 claimStart;

    function setUp() public {
        admin = makeAddr("admin");
        (allocationSetter, allocationSetterPrivateKey) = makeAddrAndKey("allocationSetter");
        originalTokenHolder = makeAddr("originalTokenHolder");
        token = new Zora(admin);
        claimStart = block.timestamp + 60 hours;
        claim = new ZoraTokenCommunityClaim(allocationSetter, admin, address(token));

        // Fund claim contract with tokens
        vm.startPrank(admin);
        address[] memory claimAddress = new address[](1);
        uint256[] memory claimAmount = new uint256[](1);
        claimAddress[0] = originalTokenHolder;
        claimAmount[0] = 1_000_000_000 * 1e18;
        token.initialize(claimAddress, claimAmount, "testing");
        vm.stopPrank();

        vm.prank(originalTokenHolder);
        token.approve(address(claim), 1_000_000_000 * 1e18);
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

    function testConstructorRevertsIfTokenIsNotContract() public {
        vm.expectRevert(IZoraTokenCommunityClaim.InvalidToken.selector);
        address notAContract = makeAddr("not-a-contract");
        new ZoraTokenCommunityClaim(allocationSetter, admin, notAContract);
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

    function testCannotSetAllocationsAfterClaimStart() public {
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
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupAlreadyCompleted.selector);
        claim.setAllocations(compactAllocations);
    }

    function testCannotSetAllocationsIfSetupCompleted() public {
        address[] memory accounts = new address[](0);
        uint96[] memory amounts = new uint96[](0);

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.assertFalse(claim.claimIsOpen());

        vm.prank(allocationSetter);
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupAlreadyCompleted.selector);
        claim.setAllocations(compactAllocations);
    }

    function testCannotCompleteSetupIfNotAdmin() public {
        vm.prank(makeAddr("not-admin"));
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAdmin.selector);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);
    }

    function testCannotCompleteSetupIfAlreadyCompleted() public {
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.prank(admin);
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupAlreadyCompleted.selector);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);
    }

    function testCannotCompleteSetupWithPastClaimStart() public {
        // Try to complete setup with past timestamp
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(IZoraTokenCommunityClaim.ClaimStartInPast.selector, block.timestamp - 1, block.timestamp));
        claim.completeAllocationSetup(block.timestamp - 1, originalTokenHolder);
        vm.stopPrank();
    }

    function testTotalAllocationsIsCorrect() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");

        // Initial setup with user1 and user2
        address[] memory accounts = new address[](2);
        uint96[] memory amounts = new uint96[](2);

        accounts[0] = user1;
        amounts[0] = 100 * 1e18;
        accounts[1] = user2;
        amounts[1] = 400 * 1e18;

        vm.startPrank(allocationSetter);
        // First allocation - verify total
        claim.setAllocations(toCompactAllocations(accounts, amounts));
        assertEq(claim.totalAllocated(), (100 + 400) * 1e18);

        // Reduce user2's allocation - verify total updates correctly
        amounts[1] = 50 * 1e18;
        claim.setAllocations(toCompactAllocations(accounts, amounts));
        assertEq(claim.totalAllocated(), (100 + 50) * 1e18);

        // Increase user1's allocation - verify total updates correctly
        amounts[0] = 300 * 1e18;
        claim.setAllocations(toCompactAllocations(accounts, amounts));
        assertEq(claim.totalAllocated(), (300 + 50) * 1e18);

        // Update user1 to have 10 allocation and add user3
        amounts[0] = 10 * 1e18;
        accounts[1] = user3;
        amounts[1] = 50 * 1e18;
        claim.setAllocations(toCompactAllocations(accounts, amounts));
        assertEq(claim.totalAllocated(), (10 + 50 + 50) * 1e18);

        vm.stopPrank();

        // Complete setup and verify final token balance
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);
        assertEq(token.balanceOf(address(claim)), (10 + 50 + 50) * 1e18, "Final token balance incorrect");
    }

    function testBasicClaim() public {
        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        // Allocation not setup yet
        assertEq(claim.accountClaim(user1).claimed, false);
        assertEq(claim.accountClaim(user1).allocation, 0);

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        // Allocation not claimed yet
        assertEq(claim.accountClaim(user1).claimed, false);
        assertEq(claim.accountClaim(user1).allocation, amount);

        vm.expectEmit(true, true, true, true);
        emit IZoraTokenCommunityClaim.AllocationSetupCompleted(amount, claimStart);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.assertFalse(claim.claimIsOpen());

        // Warp to claim period
        vm.warp(claimStart + 1);

        vm.assertTrue(claim.claimIsOpen());

        // Claim
        vm.prank(user1);
        vm.expectEmit(true, true, true, true);
        emit IZoraTokenCommunityClaim.Claimed(user1, user1, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(claim), user1, amount);
        claim.claim(user1);

        // Verify claim data
        assertEq(token.balanceOf(user1), amount);
        assertEq(claim.allocations(user1), amount);
        assertEq(claim.hasClaimed(user1), true);
        assertEq(claim.accountClaim(user1).claimed, true);
        assertEq(claim.accountClaim(user1).allocation, amount);
    }

    function testCannotClaimBeforeCompleteOrStart() public {
        address user1 = makeAddr("user1");

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = 100 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(user1);
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupNotCompleted.selector);
        claim.claim(user1);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.prank(user1);
        vm.expectRevert(IZoraTokenCommunityClaim.ClaimNotOpen.selector);
        claim.claim(user1);
    }

    function testCannotClaimWithNoAllocation() public {
        address user1 = makeAddr("user1");

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        vm.warp(claimStart + 1);

        vm.prank(user1);
        vm.expectRevert(IZoraTokenCommunityClaim.NoAllocation.selector);
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

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Create signature
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Claim with signature
        vm.prank(signer);
        vm.expectEmit(true, true, true, true);
        emit IZoraTokenCommunityClaim.Claimed(signer, recipient, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(claim), recipient, amount);
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

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

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

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        uint256 deadline = block.timestamp - 1;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IZoraTokenCommunityClaim.SignatureExpired.selector, deadline, block.timestamp));
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

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.warp(claimStart + 1);

        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IZoraTokenCommunityClaim.InvalidSignature.selector);
        claim.claimWithSignature(signer, recipient, deadline, signature);
    }

    function testCannotClaimWithWrongClaimTo() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        address recipient = makeAddr("recipient");
        address wrongRecipient = makeAddr("wrongRecipient");
        uint96 amount = 100 * 1e18;

        // Set allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = signer;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // Warp to claim period
        vm.warp(claimStart + 1);

        // Create signature
        uint256 deadline = block.timestamp + 1 days;
        bytes32 digest = _getSignatureDigest(signer, recipient, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Claim with signature
        vm.expectRevert(IZoraTokenCommunityClaim.InvalidSignature.selector);
        claim.claimWithSignature(signer, wrongRecipient, deadline, signature);
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

        vm.prank(allocationSetter);
        claim.setAllocations(compactAllocations);

        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

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

        vm.prank(allocationSetter);
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

    function testFuzz_AllocationChangesPreserveConsistency(uint8 initialAmount, uint8 newAmount, uint8 finalAmount) public {
        // Bound the values to reasonable ranges to avoid extreme values
        address user = makeAddr("fuzzUser");

        // First set initial allocation
        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user;
        amounts[0] = initialAmount;

        // Set initial allocation
        vm.prank(allocationSetter);
        claim.setAllocations(toCompactAllocations(accounts, amounts));

        // Verify initial allocation was set correctly
        assertEq(claim.allocations(user), initialAmount);
        assertEq(claim.totalAllocated(), initialAmount);

        // Now change the allocation to the new amount
        amounts[0] = newAmount;
        vm.prank(allocationSetter);
        claim.setAllocations(toCompactAllocations(accounts, amounts));

        // Verify allocation was updated correctly
        assertEq(claim.allocations(user), newAmount);

        // Verify total allocated is consistent with the user's allocation
        assertEq(claim.totalAllocated(), newAmount);

        // Now change the allocation to the final amount
        amounts[0] = finalAmount;
        vm.prank(allocationSetter);
        claim.setAllocations(toCompactAllocations(accounts, amounts));

        // Verify allocation was updated correctly
        assertEq(claim.allocations(user), finalAmount);

        // Verify total allocated is consistent with the user's allocation
        assertEq(claim.totalAllocated(), finalAmount);
    }

    function _getSetAllocationsDigest(bytes32[] memory packedData, bytes32 nonce) private view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(keccak256("SetAllocations(bytes32[] packedData,bytes32 nonce)"), keccak256(abi.encodePacked(packedData)), nonce)
        );

        return keccak256(abi.encodePacked("\x19\x01", claim.getDomainSeparator(), structHash));
    }

    function testSetAllocationsWithSignature() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        address[] memory accounts = new address[](2);
        uint96[] memory amounts = new uint96[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        amounts[0] = 100 * 1e18;
        amounts[1] = 200 * 1e18;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);
        bytes32 nonce = keccak256("test-nonce");

        // Create signature
        bytes32 digest = _getSetAllocationsDigest(compactAllocations, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(allocationSetterPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify nonce was not used
        assertFalse(claim.nonceUsed(allocationSetter, nonce));

        // Set allocations with signature
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);

        // Verify nonce was used
        assertTrue(claim.nonceUsed(allocationSetter, nonce));

        // Verify allocations were set correctly
        assertEq(claim.allocations(user1), 100 * 1e18);
        assertEq(claim.allocations(user2), 200 * 1e18);
    }

    function testCannotReuseNonceForSetAllocations() public {
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

        // First set should succeed
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);

        // Second set with same nonce should fail
        vm.expectRevert(abi.encodeWithSelector(UnorderedNonces.InvalidAccountNonce.selector, allocationSetter, nonce));
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);
    }

    function testCannotSetAllocationsWithWrongSigner() public {
        uint256 wrongPrivateKey = 0x5678;

        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);
        bytes32 nonce = keccak256("test-nonce");

        // Create signature with wrong key
        bytes32 digest = _getSetAllocationsDigest(compactAllocations, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempt to set allocations should fail
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAllocationSetter.selector);
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);
    }

    function testCannotSetAllocationsWithBadSignature() public {
        address user1 = makeAddr("user1");
        uint96 amount = 100 * 1e18;

        address[] memory accounts = new address[](1);
        uint96[] memory amounts = new uint96[](1);
        accounts[0] = user1;
        amounts[0] = amount;

        bytes32[] memory compactAllocations = toCompactAllocations(accounts, amounts);
        bytes32 nonce = keccak256("test-nonce");

        // Create signature with wrong key
        bytes memory badSignature = abi.encode("bad-signature");

        // Attempt to set allocations should fail
        vm.expectRevert(IZoraTokenCommunityClaim.InvalidSignature.selector);
        claim.setAllocationsWithSignature(compactAllocations, nonce, badSignature);
    }

    function testCannotSetAllocationsWithSignatureAfterSetupComplete() public {
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

        // Attempt to set allocations should fail
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupAlreadyCompleted.selector);
        claim.setAllocationsWithSignature(compactAllocations, nonce, signature);
    }

    function testOnlyAdminCanUpdateClaimStart() public {
        // First complete the allocation setup
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // New claim start time (future)
        uint256 newClaimStart = block.timestamp + 2 hours;

        // Non-admin tries to update claim start
        address nonAdmin = makeAddr("nonAdmin");
        vm.prank(nonAdmin);
        vm.expectRevert(IZoraTokenCommunityClaim.OnlyAdmin.selector);
        claim.updateClaimStart(newClaimStart);

        // Admin should be able to update claim start
        vm.prank(admin);
        claim.updateClaimStart(newClaimStart);

        // Verify claim start was updated
        assertEq(claim.claimStart(), newClaimStart);
    }

    function testCannotUpdateClaimStartBeforeAllocationSetupComplete() public {
        // Try to update claim start before allocation setup is complete
        uint256 newClaimStart = block.timestamp + 2 hours;

        vm.prank(admin);
        vm.expectRevert(IZoraTokenCommunityClaim.AllocationSetupNotCompleted.selector);
        claim.updateClaimStart(newClaimStart);
    }

    function testFuzz_CannotUpdateClaimStartAfterClaimOpened(int8 timeBeforeClaimStart, int8 timeAhead) public {
        // First complete the allocation setup
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // Warp to specified time (before or after claim has started)
        vm.warp(uint256(int256(claimStart) + timeBeforeClaimStart));

        uint256 newClaimStart = uint256(int256(block.timestamp) + timeAhead);

        // Two potential failure conditions:
        // 1. Claim period has already started (timeBeforeClaimStart >= 0)
        // 2. New claim start is in the past or present (timeAhead <= 0)

        vm.prank(admin);

        // The contract checks for claim opened first, then checks if the new time is in the past
        // We need to match this order in our test expectations
        if (timeBeforeClaimStart >= 0) {
            vm.expectRevert(IZoraTokenCommunityClaim.ClaimOpened.selector);
        } else if (timeAhead <= 0) {
            vm.expectRevert(abi.encodeWithSelector(IZoraTokenCommunityClaim.ClaimStartInPast.selector, newClaimStart, block.timestamp));
        }

        claim.updateClaimStart(newClaimStart);
    }

    function testCannotUpdateClaimStartToPast() public {
        // First complete the allocation setup
        vm.prank(admin);
        claim.completeAllocationSetup(claimStart, originalTokenHolder);

        // Try to set a past timestamp (current time minus 1 second)
        uint256 pastTimestamp = block.timestamp - 1;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IZoraTokenCommunityClaim.ClaimStartInPast.selector, pastTimestamp, block.timestamp));
        claim.updateClaimStart(pastTimestamp);
    }
}
