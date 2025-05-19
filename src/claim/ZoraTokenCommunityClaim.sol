// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IZoraTokenCommunityClaim} from "./IZoraTokenCommunityClaim.sol";
import {UnorderedNonces} from "../utils/UnorderedNonces.sol";

/// @title Zora Token Community Claim
/// @notice ERC20 token distribution contract for Zora community members
/// @dev Implements a gas-efficient token claiming method with the following features:
///      - Pre-allocated claims stored directly in contract storage (vs merkle proofs), allowing for gas-efficient
///        claim process and more claims allowed per block.
///      - Two-phase setup: 1) allocation setting by designated setter 2) admin finalizes with transfer of tokens to claim contract
///      - Multiple claim options: direct claim, and claim with signature.
///      - Supports both EOA and smart contract wallet claiming.
contract ZoraTokenCommunityClaim is EIP712, UnorderedNonces, IZoraTokenCommunityClaim {
    // Type hash for the ClaimWithSignature struct
    bytes32 private constant CLAIM_TYPEHASH = keccak256("ClaimWithSignature(address user,address claimTo,uint256 deadline)");
    bytes32 private constant SET_ALLOCATIONS_TYPEHASH = keccak256("SetAllocations(bytes32[] packedData,bytes32 nonce)");
    string private constant DOMAIN_NAME = "ZoraTokenCommunityClaim";
    string private constant DOMAIN_VERSION = "1";

    IERC20 public immutable token;

    mapping(address => AccountClaim) internal accountClaims;

    uint256 public totalAllocated;
    bool public allocationSetupComplete;

    address public immutable allocationSetter;
    address public immutable admin;
    uint256 public claimStart;

    /// @notice Constructor
    /// @param _allocationSetter The address of the account that can set allocations.
    /// @param _admin The address of the account that can complete the setup. Should be a multisig.
    /// @param _token The address of the token to be distributed
    constructor(address _allocationSetter, address _admin, address _token) EIP712(DOMAIN_NAME, DOMAIN_VERSION) {
        if (_token.code.length == 0) {
            revert InvalidToken();
        }

        token = IERC20(_token);
        allocationSetter = _allocationSetter;
        admin = _admin;
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function allocations(address account) public view virtual returns (uint256) {
        return uint256(accountClaims[account].allocation);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function hasClaimed(address account) public view virtual returns (bool) {
        return accountClaims[account].claimed;
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function accountClaim(address account) public view virtual returns (AccountClaim memory) {
        return accountClaims[account];
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function setAllocations(bytes32[] calldata packedData) external {
        _checkCanSetAllocations(msg.sender);
        _setAllocations(packedData);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function setAllocationsWithSignature(bytes32[] calldata packedData, bytes32 nonce, bytes calldata signature) external {
        // Verify signature
        bytes32 structHash = keccak256(abi.encode(SET_ALLOCATIONS_TYPEHASH, keccak256(abi.encodePacked(packedData)), nonce));
        bytes32 digest = _hashTypedDataV4(structHash);

        // recover the signature, and catch and throw a clean error if its a bad signature
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(digest, signature);
        require(error == ECDSA.RecoverError.NoError, InvalidSignature());

        // validate that the recovered address can set allocations and that the allocation setup is not complete
        _checkCanSetAllocations(recovered);

        // Use the nonce to prevent replay attacks
        _useCheckedNonce(allocationSetter, nonce);

        _setAllocations(packedData);
    }

    function _setAllocations(bytes32[] calldata packedData) internal {
        uint256 updatedTotalAllocated = totalAllocated;

        for (uint256 i = 0; i < packedData.length; i++) {
            // Extract address from first 160 bits
            address account = address(uint160(uint256(packedData[i])));

            // Extract allocation from remaining bits (shift right by 160 bits)
            uint96 amount = uint96(uint256(packedData[i]) >> 160);

            // Handle both increase and decrease in allocation safely
            uint96 existingAllocation = accountClaims[account].allocation;
            if (amount > existingAllocation) {
                updatedTotalAllocated += amount - existingAllocation;
            } else {
                updatedTotalAllocated -= existingAllocation - amount;
            }

            // Store the allocation
            accountClaims[account].allocation = amount;
        }

        totalAllocated = updatedTotalAllocated;

        emit AllocationsSet(packedData);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function claimWithSignature(address account, address claimTo, uint256 deadline, bytes calldata signature) external override {
        require(block.timestamp <= deadline, SignatureExpired(deadline, block.timestamp));

        // Verify signature
        // Note: We don't need a nonce for replay protection because:
        // 1. Allocations can only be set before claiming starts
        // 2. Each address can only claim once (tracked by hasClaimed mapping)
        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPEHASH, account, claimTo, deadline));

        bytes32 digest = _hashTypedDataV4(structHash);

        require(SignatureChecker.isValidSignatureNow(account, digest, signature), InvalidSignature());

        _claim(account, claimTo);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function completeAllocationSetup(uint256 claimStart_, address transferBalanceFrom) external {
        require(msg.sender == admin, OnlyAdmin());
        require(!allocationSetupComplete, AllocationSetupAlreadyCompleted());
        require(claimStart_ > block.timestamp, ClaimStartInPast(claimStart_, block.timestamp));

        allocationSetupComplete = true;
        claimStart = claimStart_;

        emit AllocationSetupCompleted(totalAllocated, claimStart_);

        SafeERC20.safeTransferFrom(token, transferBalanceFrom, address(this), totalAllocated);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function updateClaimStart(uint256 claimStart_) external {
        _checkCanUpdateClaimStart(claimStart_);
        claimStart = claimStart_;
    }

    function _checkCanUpdateClaimStart(uint256 claimStart_) internal view virtual {
        // only the admin can update the claim start
        require(msg.sender == admin, OnlyAdmin());
        // claim start can only be updated if allocation setup is complete
        require(allocationSetupComplete, AllocationSetupNotCompleted());
        // claim start can only be updated if claim start hasn't elapsed
        require(block.timestamp < claimStart, ClaimOpened());
        // claim start can only be updated to a future time
        require(claimStart_ > block.timestamp, ClaimStartInPast(claimStart_, block.timestamp));
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function claim(address claimTo) external override {
        _claim(msg.sender, claimTo);
    }

    function _claim(address account, address claimTo) internal {
        _checkCanClaim();
        if (accountClaims[account].allocation == 0) {
            revert NoAllocation();
        }
        if (accountClaims[account].claimed) {
            revert AlreadyClaimed();
        }

        uint256 amount = uint256(accountClaims[account].allocation);
        // Mark as claimed before transfer
        accountClaims[account].claimed = true;

        emit Claimed(account, claimTo, amount);
        SafeERC20.safeTransfer(token, claimTo, amount);
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function getDomainSeparator() public view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /// @inheritdoc IZoraTokenCommunityClaim
    function claimIsOpen() public view returns (bool) {
        return allocationSetupComplete && block.timestamp >= claimStart;
    }

    function _checkCanSetAllocations(address sender) internal view virtual {
        require(!allocationSetupComplete, AllocationSetupAlreadyCompleted());
        require(sender == allocationSetter, OnlyAllocationSetter());
    }

    function _checkCanClaim() internal view virtual {
        require(allocationSetupComplete, AllocationSetupNotCompleted());
        require(block.timestamp >= claimStart, ClaimNotOpen());
    }
}
