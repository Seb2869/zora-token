// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IZoraTokenCommunityClaim
/// @notice ERC20 token distribution contract for Zora community members
/// @dev Implements a gas-efficient token claiming method with the following features:
///      - Pre-allocated claims stored directly in contract storage (vs merkle proofs), allowing for gas-efficient
///        claim process and more claims allowed per block.
///      - Two-phase setup: 1) allocation setting by designated setter 2) admin finalizes with transfer of tokens to claim contract
///      - Multiple claim options: direct claim, and claim with signature.
///      - Supports both EOA and smart contract wallet claiming.
interface IZoraTokenCommunityClaim {
    struct AccountClaim {
        uint96 allocation;
        bool claimed;
    }
    /// @notice Emitted when allocations are set
    /// @param allocations The packed allocation data (address + amount)
    event AllocationsSet(bytes32[] allocations);

    /// @notice Emitted when tokens are claimed
    /// @param account The account that had the allocation
    /// @param claimTo The address that received the tokens
    /// @param amount The amount of tokens claimed
    event Claimed(address indexed account, address indexed claimTo, uint256 amount);

    /// @notice Emitted when the allocation setup is completed
    /// @param totalAllocation The total allocation amount
    /// @param claimStart The claim start timestamp
    event AllocationSetupCompleted(uint256 totalAllocation, uint256 claimStart);

    /// @notice Error thrown when a account tries to claim without having an allocation
    error NoAllocation();

    /// @notice Error thrown when a account tries to claim more than once
    error AlreadyClaimed();

    /// @notice Error thrown when a signature is invalid
    error InvalidSignature();

    /// @notice Error thrown when a signature has expired
    error SignatureExpired(uint256 deadline, uint256 currentTime);

    /// @notice Error thrown when the token is invalid
    error InvalidToken();

    /// @notice Error thrown when a non-admin tries to perform an admin-only action
    error OnlyAdmin();

    /// @notice Error thrown when a non-allocation setter tries to perform an allocation setter-only action
    error OnlyAllocationSetter();

    /// @notice Error thrown when trying to claim before the claim period has started
    error ClaimNotOpen();

    /// @notice Error thrown when trying to set allocations after the claim period has started
    error ClaimOpened();

    /// @notice Error thrown when trying to set allocations after the claim period has started
    error AllocationSetupAlreadyCompleted();

    /// @notice Error thrown when the allocation setup is not completed
    error AllocationSetupNotCompleted();

    /// @notice Error thrown when the claim start timestamp is in the past
    error ClaimStartInPast(uint256 claimStart, uint256 currentTime);

    /// @notice Returns the token contract address
    /// @return The token contract address
    function token() external view returns (IERC20);

    /// @notice Returns the allocation for a account
    /// @param account The account address
    /// @return The allocation amount
    function allocations(address account) external view returns (uint256);

    /// @notice Returns whether a  has claimed their allocation
    /// @param account The account address
    /// @return Whether the account has claimed
    function hasClaimed(address account) external view returns (bool);

    /// @notice Returns the account claim for a account
    /// @param account The account address
    /// @return The account claim
    function accountClaim(address account) external view returns (AccountClaim memory);

    /// @notice Claims tokens for the caller
    /// @param claimTo The address to send the tokens to
    function claim(address claimTo) external;

    /// @notice Claims tokens on behalf of a account with their signature
    /// @param account The account who is delegating their claim
    /// @param claimTo The address to send the tokens to
    /// @param deadline The deadline for the signature to be valid
    /// @param signature The signature authorizing the claim
    function claimWithSignature(address account, address claimTo, uint256 deadline, bytes calldata signature) external;

    /// @notice Returns the domain separator used for EIP-712 signatures
    /// @return The domain separator
    function getDomainSeparator() external view returns (bytes32);

    /// @notice Returns the admin address
    /// @return The admin address
    function admin() external view returns (address);

    /// @notice Returns the claim start timestamp
    /// @return The claim start timestamp
    function claimStart() external view returns (uint256);

    /// @notice Returns whether claiming is open
    /// @return Whether claiming is open
    function claimIsOpen() external view returns (bool);

    /// @notice Sets allocations using packed data format with a signature
    /// @param packedData Array of packed address+allocation data
    /// @param nonce A random nonce to prevent replay attacks
    /// @param signature The signature authorizing the allocation setting
    function setAllocationsWithSignature(bytes32[] calldata packedData, bytes32 nonce, bytes calldata signature) external;

    /// @notice Sets allocations using packed data format
    /// @param packedData Array of packed address+allocation data
    function setAllocations(bytes32[] calldata packedData) external;

    /// @notice Updates the claim start timestamp, if the claim has not started yet and the allocation setup is complete.
    /// @param claimStart_ The new claim start timestamp
    /// @dev Only the admin can update the claim start timestamp.
    function updateClaimStart(uint256 claimStart_) external;

    /// @notice Returns the allocation setter address
    /// @return The allocation setter address
    function allocationSetter() external view returns (address);

    /// @notice Returns the total amount of tokens allocated
    /// @return The total allocation amount
    function totalAllocated() external view returns (uint256);

    /// @notice Returns whether the allocation setup is complete
    /// @return Whether the allocation setup is complete
    function allocationSetupComplete() external view returns (bool);

    /// @notice Completes the set allocations phase by transferring the total allocated tokens to the claim contract,
    /// and setting the claim start time.
    /// @param claimStart_ The timestamp when the claim will be open to the public
    /// @param transferBalanceFrom The address to transfer the tokens from
    /// @dev Can only be called by the admin
    function completeAllocationSetup(uint256 claimStart_, address transferBalanceFrom) external;
}
