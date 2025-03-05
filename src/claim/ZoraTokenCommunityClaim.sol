// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title Zora Token Claim
/// @notice Contract for distributing tokens to the Zora community
/// @dev Allows an admin to set allocations in advance using a storage mapping of addresses to amounts,
/// avoiding the blockspace congestion that can occur with merkle proofs during claiming
contract ZoraTokenCommunityClaim is EIP712 {
    string private constant DOMAIN_NAME = "ZoraTokenCommunityClaim";
    string private constant DOMAIN_VERSION = "1";

    // Type hash for the ClaimWithSignature struct
    bytes32 private constant CLAIM_TYPEHASH = keccak256("ClaimWithSignature(address user,address claimTo,uint256 deadline)");

    address public immutable admin;
    uint256 public immutable claimStart;
    IERC20 public immutable token;

    // Compact allocations stored as uint96 (token count, will be multiplied by 1e18)
    mapping(address => uint96) private compactAllocations;
    mapping(address => bool) public hasClaimed;

    error OnlyAdmin();
    error ClaimNotOpen();
    error ClaimOpened();
    error ArrayLengthMismatch();
    error NoAllocation();
    error AlreadyClaimed();
    error InvalidSignature();
    error SignatureExpired();

    event AllocationsSet(bytes32[] indexed allocations);
    event Claimed(address indexed account, address indexed claimTo, uint256 amount);

    constructor(address _admin, uint256 _claimStart, address _token) EIP712(DOMAIN_NAME, DOMAIN_VERSION) {
        admin = _admin;
        claimStart = _claimStart;
        token = IERC20(_token);
    }

    // Public view function to get the full allocation amount with 18 decimals
    function allocations(address user) public view returns (uint256) {
        return uint256(compactAllocations[user]);
    }

    /// @notice Sets allocations using packed data format for gas efficiency
    /// @dev Each bytes32 contains an address (160 bits) and allocation (96 bits)
    /// @param packedData Array of packed address+allocation data
    function setAllocations(bytes32[] calldata packedData) external {
        require(msg.sender == admin, OnlyAdmin());
        require(!claimIsOpen(), ClaimOpened());

        for (uint256 i = 0; i < packedData.length; i++) {
            // Extract address from first 160 bits
            address user = address(uint160(uint256(packedData[i])));

            // Extract allocation from remaining bits (shift right by 160 bits)
            uint96 amount = uint96(uint256(packedData[i]) >> 160);

            // Store the allocation
            compactAllocations[user] = amount;
        }

        emit AllocationsSet(packedData);
    }

    function claimIsOpen() public view returns (bool) {
        return block.timestamp >= claimStart;
    }

    function claim(address _claimTo) external {
        _claim(msg.sender, _claimTo);
    }

    /// @notice Claims tokens on behalf of a user with their signature
    /// @param _user The user who is delegating their claim
    /// @param _claimTo The address to send the tokens to
    /// @param _deadline The deadline for the signature to be valid
    /// @param _signature The signature authorizing the claim
    function claimWithSignature(address _user, address _claimTo, uint256 _deadline, bytes calldata _signature) external {
        require(block.timestamp <= _deadline, SignatureExpired());

        // Verify signature
        // Note: We don't need a nonce for replay protection because:
        // 1. Allocations can only be set before claiming starts
        // 2. Each address can only claim once (tracked by hasClaimed mapping)
        bytes32 structHash = keccak256(abi.encode(CLAIM_TYPEHASH, _user, _claimTo, _deadline));

        bytes32 digest = _hashTypedDataV4(structHash);

        if (!SignatureChecker.isValidSignatureNow(_user, digest, _signature)) {
            revert InvalidSignature();
        }

        _claim(_user, _claimTo);
    }

    function _claim(address _user, address _claimTo) private {
        require(claimIsOpen(), ClaimNotOpen());
        require(compactAllocations[_user] > 0, NoAllocation());
        require(!hasClaimed[_user], AlreadyClaimed());

        uint256 amount = uint256(compactAllocations[_user]);
        // Mark as claimed before transfer
        hasClaimed[_user] = true;

        emit Claimed(_user, _claimTo, amount);
        SafeERC20.safeTransfer(token, _claimTo, amount);
    }

    // Make the domain separator accessible for testing
    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
