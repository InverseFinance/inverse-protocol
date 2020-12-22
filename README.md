# Inverse Protocol

Converts yield provided by a lending protocol or yield optimizer to a different token.

## Overview

1. Users deposit an underlying token (e.g. DAI) to a Vault and receives a vault token 1-1 with underlying.
2. The vault uses a strategy (e.g. CTokenStrat) to deposit the underlying to a yield generator.
3. The Harvester continuously swaps yield to a target token (e.g. ETH) and distributes it to vault token holders in the form of dividends.
4. Vault token holders can withdraw underlying and the target token at any time.

## Development

# Lint
yarn lint - Lints all
yarn lint-js - Lints JS files
yarn lint-contracts - Lints solidity files under "contracts/"

# Compile
yarn compile

# Run
Forking:
yarn fork script.js
e.g. yarn fork scripts/1_deployLpHarvester.js

Testnet ropsten, rinkeby, ganache:
e.g. yarn reposten scripts/1_deployLpHarvester.js
e.g. yarn rinkeby scripts/1_deployLpHarvester.js
e.g. yarn ganache scripts/1_deployLpHarvester.js
