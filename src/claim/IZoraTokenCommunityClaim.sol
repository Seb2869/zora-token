// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IZoraTokenCommunityClaim
 * @notice Interface for the Zora Token Community Claim contract
 */
interface IZoraTokenCommunityClaim {
    /**
     * @notice Emitted when allocations are set
     * @param allocations The packed allocation data (address + amount)
     */
    event AllocationsSet(bytes32[] indexed allocations);

    /**
     * @notice Emitted when tokens are claimed
     * @param account The account that had the allocation
     * @param claimTo The address that received the tokens
     * @param amount The amount of tokens claimed
     */
    event Claimed(address indexed account, address indexed claimTo, uint256 amount);

    /**
     * @notice Error thrown when a non-admin tries to perform an admin-only action
     */
    error OnlyAdmin();

    /**
     * @notice Error thrown when trying to claim before the claim period has started
     */
    error ClaimNotOpen();

    /**
     * @notice Error thrown when trying to set allocations after the claim period has started
     */
    error ClaimOpened();

    /**
     * @notice Error thrown when a user tries to claim without having an allocation
     */
    error NoAllocation();

    /**
     * @notice Error thrown when a user tries to claim more than once
     */
    error AlreadyClaimed();

    /**
     * @notice Error thrown when a signature is invalid
     */
    error InvalidSignature();

    /**
     * @notice Error thrown when a signature has expired
     */
    error SignatureExpired();

    /**
     * @notice Returns the admin address
     * @return The admin address
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the claim start timestamp
     * @return The claim start timestamp
     */
    function claimStart() external view returns (uint256);

    /**
     * @notice Returns the token contract address
     * @return The token contract address
     */
    function token() external view returns (IERC20);

    /**
     * @notice Returns the allocation for a user
     * @param user The user address
     * @return The allocation amount
     */
    function allocations(address user) external view returns (uint256);

    /**
     * @notice Returns whether a user has claimed their allocation
     * @param user The user address
     * @return Whether the user has claimed
     */
    function hasClaimed(address user) external view returns (bool);

    /**
     * @notice Sets allocations using packed data format for gas efficiency
     * @dev Each bytes32 contains an address (160 bits) and allocation (96 bits)
     * @param packedData Array of packed address+allocation data
     */
    function setAllocations(bytes32[] calldata packedData) external;

    /**
     * @notice Returns whether claiming is open
     * @return Whether claiming is open
     */
    function claimIsOpen() external view returns (bool);

    /**
     * @notice Claims tokens for the caller
     * @param _claimTo The address to send the tokens to
     */
    function claim(address _claimTo) external;

    /**
     * @notice Claims tokens on behalf of a user with their signature
     * @param _user The user who is delegating their claim
     * @param _claimTo The address to send the tokens to
     * @param _deadline The deadline for the signature to be valid
     * @param _signature The signature authorizing the claim
     */
    function claimWithSignature(address _user, address _claimTo, uint256 _deadline, bytes calldata _signature) external;

    /**
     * @notice Returns the domain separator used for EIP-712 signatures
     * @return The domain separator
     */
    function getDomainSeparator() external view returns (bytes32);
}
