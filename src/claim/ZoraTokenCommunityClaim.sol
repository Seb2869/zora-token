// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Zora Token Claim
/// @notice Contract for distributing tokens to the Zora community
/// @dev Allows an admin to set allocations in advance using a storage mapping of addresses to amounts,
/// avoiding the blockspace congestion that can occur with merkle proofs during claiming
contract ZoraTokenCommunityClaim {
    address public immutable admin;
    uint256 public immutable claimStart;
    IERC20 public immutable token;

    mapping(address => uint256) public allocations;

    error OnlyAdmin();
    error ClaimNotOpen();
    error ClaimOpened();
    error ArrayLengthMismatch();
    error NoAllocation();

    event AllocationsSet(address[] indexed accounts, uint256[] amounts);
    event Claimed(address indexed account, address indexed claimTo, uint256 amount);

    constructor(address _admin, uint256 _claimStart, address _token) {
        admin = _admin;
        claimStart = _claimStart;
        token = IERC20(_token);
    }

    function setAllocations(address[] calldata _accounts, uint256[] calldata _amounts) external {
        if (_accounts.length != _amounts.length) revert ArrayLengthMismatch();
        // only admin can add allocations
        if (msg.sender != admin) revert OnlyAdmin();
        // cannot add allocations after claim has started
        if (claimIsOpen()) revert ClaimOpened();

        emit AllocationsSet(_accounts, _amounts);

        for (uint256 i = 0; i < _accounts.length; i++) {
            allocations[_accounts[i]] = _amounts[i];
        }
    }

    function claimIsOpen() public view returns (bool) {
        return block.timestamp < claimStart;
    }

    function claim(address _claimTo) external {
        if (!claimIsOpen()) revert ClaimNotOpen();
        if (allocations[msg.sender] == 0) revert NoAllocation();
        emit Claimed(msg.sender, _claimTo, allocations[msg.sender]);
        // set that allocation is claimed
        allocations[msg.sender] = 0;

        SafeERC20.safeTransfer(token, _claimTo, allocations[msg.sender]);
    }
}
