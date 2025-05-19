# Zora Token Contracts

This repository contains the contracts for the Zora token.

## Contracts

- [Zora.sol](./src/Zora.sol) - The main Zora token contract.
- [IZora.sol](./src/IZora.sol) - The Zora token contract interface.

- [ZoraTokenCommunityClaim.sol](./src/claim/ZoraTokenCommunityClaim.sol) - Main community claim contract.
- [IZoraTokenCommunityClaim.sol](./src/claim/IZoraTokenCommunityClaim.sol) - Main community claim contract interface.

## Audit Report

This project has a [Zellic Audit Report](audit%2FZora%20Token%20-%20Zellic%20Audit%20Report.pdf) at ba75438

## Setup

Install dependencies

```bash
pnpm install
```

## Run tests in watch mode

```bash
pnpm dev
```

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for instructions on deploying the token.

## Public

The public webroot for metadata is `metadata/`. Be mindful with files in that directory.
