# Zora Token Deterministic Deployment

The Zora token is deployed deterministically using the ImmutableCreate2Factory contract, which allows us to deploy a contract from an EOA at an expected address based on a salt. The minter, which is the account that mints the full supply, is set in the constructor. Anyone can deploy the contract, but only the minter can mint the initial supply.

The salt for an expected address can be mined using `cast create2`. There are some scripts to help with this process.

## 1. Preparing the Config files for Deployment

Configure `minter` and `initialMints` in [script/config/deploymentConfig.json](script/config/deploymentConfig.json):

- `minter` - account that will mint the entire supply in a single call. This should be a multisig.
- `initialMints` - array of initial mints to be made on the token.

## 2. Mining the Salt

Once this is configured, we mine the salt for the deployment. The bytecode of the contract is affected by the minter address as it is passed in to the constructor, so make sure that is configured above:

```bash
forge script script/PrepareForSaltMining.s.sol $(chains base --rpc)
```

This will print out a command to run to mine the salt. Follow the instructions to mine the salt, then update [script/config/deterministicConfig.json](script/config/deterministicConfig.json) with the new salt and expected address.

## 3. Deploying the Token

Once the salt is mined and configured, any account can deploy the token, by executing the script:

```bash
forge script script/DeployToken.s.sol $(chains base --deploy) --broadcast --verify
```

The above command will print out the call to mint the supply, which must be executed by the multisig configured as the `minter` in [script/config/deploymentConfig.json](script/config/deploymentConfig.json). The multisig's address is also printed out.

## 4. Minting the Supply

The mint supply call was printed in the previous step. If it is needed again, it can be printed out by running:

```bash
forge script script/PrintMintSupplyCall.s.sol $(chains base --rpc)
```

The call must be executed by the multisig.
