# Sodium Protocol

This repository contains the smart contracts of the Sodium Protocol. Learn more at the following:

- User docs @ https://docs.sodium.fi/
- Developer docs @ https://sodium.gitbook.io/sodium-developer-docs/

## Setup & Use

#### Environment Variables

Certain commands in this project require specific environment variables. These are as follows:

- `MAINNET_URL` - RPC URL for ETH mainnet.
- `DEPLOYMENT_MNEMONIC` - Wallet used for deploying contracts.
- `GOERLI_URL` - Used for testnet deployments.
- `TEST_PRIVATE_KEY` - Wallet used for such testnet deployments.
- `COIN_MARKET_CAP_KEY` - Used for gas cost reporting.
- `ETHERSCAN_KEY` - Used to verify contracts.

Mainnet is forked during tests. This is required as the WETH address used by the Core is hardcoded in with its mainnet value.

#### Hardhat

This repo is a `Hardhat` project.
- Install dependencies via `npm install`.
- Run the test suite using `npx hardhat test`.
- Deploy the contracts using:
  - `npx hardhat run scripts/deploy-protocol-mainnet.js` (Mainnet)
  - `npx hardhat run scripts/deploy-protocol-test.js` (Goerli)
- Upgrade the Core contract using `npx hardhat run scripts/upgrade-core.js`.
- Get current values of protocol parameters via `npx hardhat run scripts/get-protocol-state.js`.

Protocol-specific helper methods can be found in the `helpers` directory. Error meanings can be found in `core-errors.md`.

## Architecture

The contracts have the following roles:

- `SodiumCore`: an centerpiece administrative contract that performs all the loan and auction logic.
- `SodiumWalletFactory`: a factory contract that deploys new minimal wallet proxies.
- `SodiumWallet`: the implementation contract for said wallet proxies.
- `SodiumRegistry`: used by the wallet proxies to confirm the safety and permission of external calls.

## Contract addresses

Core:  0xE9fCDd73888bf11900ea28dE68B91d31e7561293
WalletFactory:  0x6775eA002F2407c8c599FB86838212Ac37DAfA39
Wallet:  0x2eDC1D4aEe62B1D0fd86D373CdC4a4E1F52f2185
Registry:  0x17b9CecA2c8F942512D6E9698C0B77361718db6D

## Audits

The contracts in this repo have been audited by PeckShield.
