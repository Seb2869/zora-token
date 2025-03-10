# Zora Token Community Claim Contract

## Overview

The Zora Token Community Claim contract enables secure token distribution to community members. It provides a simple way for users to claim their allocated tokens directly or delegate the claim to another address using signatures.

## Key Features

### Immutability

- The token claim contract is immutable.
- An admin can set token allocations until the claim period starts. Once the claim period starts, token allocations cannot be modified. Tokens cannot be retrieved by the admin and the claim period is indefinite.
- Allowed wallets can claim their allocated tokens directly or delegate the claim to another address using signatures.
- Any unclaimed tokens remain in the community claim contract indefinitely.
- Tokens can only be transferred out via successful claims - neither the admin nor the Zora token contract can withdraw them.

### Two-Phase Distribution

1. **Setup Phase (Before Claim Period)**

   - Claim contract is deployed with immutable parameters: admin address and Zora token contract.
   - Admin can set token allocations. An allocation is a pair of address and amount.
   - Claim contract is transferred the entire community allocation.
   - Once transferred, tokens are locked in the contract until claimed by allocated addresses.

2. **Claim Phase**
   - Begins at predetermined timestamp
   - Users can claim their allocated tokens
   - Each address can only claim once
   - Allocations cannot be modified during this phase

### Flexible Claiming Methods

1. **Direct Claim**

   - User calls claim function directly to claim their allocation
   - Can specify a different address to receive the tokens
   - Claimed tokens are transferred to the recipient address

2. **Signature-Based Claim**
   - User signs a message off-chain (EIP-712 format) that includes the recipient address for their allocation
   - Anyone can submit the signed message to claim on user's behalf
   - Supports both EOA and smart wallet signatures
   - Includes deadline to limit signature validity period
   - Enables gas-less claiming and delegation
   - Signatures cannot be reused (allocation is cleared after claim)
