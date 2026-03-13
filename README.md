Here's your README fully translated to English:

---

# Foundry ZK Private Lending Protocol

# Introduction
This is a decentralized stablecoin project built with Foundry, upgraded to a **Zero-Knowledge (ZK) Private Lending Protocol**. The protocol combines traditional DeFi stablecoin functionality with advanced privacy-preserving technology, offering users a secure and private lending experience.

## Core Features

### 🏛️ Traditional Stablecoin Functions
- **Over-collateralization**: Supports WETH and WBTC as collateral
- **Algorithmic Stability**: DSC token pegged 1:1 to USD
- **Decentralized Minting**: Users can freely mint and burn DSC
- **Automated Liquidation**: Liquidation mechanism to maintain protocol health

### 🔒 Zero-Knowledge Privacy Features
- **Private Deposits/Lending**: Protect transaction privacy using ZK proofs
- **Credit Score Proof**: Zero-knowledge based credit assessment system
- **MEV-Protected Auctions**: Privacy-preserving MEV auction mechanism
- **Liquidation Proof**: Proof system to prevent malicious liquidations
- **Merkle Tree Management**: Efficient privacy data structure

## Architecture Modules

### Core Contracts
- **DSCEngine**: Stablecoin engine handling collateral, minting, and liquidation
- **DecentralizedStableCoin**: ERC20 stablecoin token
- **ZKVerifier**: Zero-knowledge proof verifier
- **MerkleTreeManager**: Merkle tree manager

### ZK Privacy Modules
- **PrivateLendingCore**: Core private lending functionality
- **ZKLiquidationProof**: Liquidation protection proof
- **ZKMEVAuction**: MEV auction system
- **ZKCreditScore**: Credit score proof
- **PrivacyRegistry**: User privacy registration

## Table of Contents
- [Introduction](#introduction)
- [Quick Start](#quick-start)
  - [Requirements](#requirements)
  - [Quick Start](#quick-start-1)
- [Usage](#usage)
  - [Start Local Node](#start-local-node)
  - [Install Dependencies](#install-dependencies)
  - [Deploy](#deploy)
  - [Deploy to Other Networks](#deploy-to-other-networks)
  - [Testing](#testing)
  - [Test Coverage](#test-coverage)
- [Deploy to Testnet or Mainnet](#deploy-to-testnet-or-mainnet)
- [Scripts](#scripts)
- [Estimate Gas](#estimate-gas)
- [Formatting](#formatting)
- [Contributing](#contributing)
- [Thank You!](#thank-you)

# Quick Start

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You're good to go if running `git --version` shows something like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You're good to go if running `forge --version` shows `forge 1.4.x (2025-10-14)`

## Quick Start

```bash
git clone https://github.com/Maxence90/foundry-defi-stablecoin
cd foundry-defi-stablecoin
forge install
forge build
```

# Usage

## Start Local Node

```bash
make anvil
```

## Install Dependencies

Install required library dependencies:

```bash
forge install smartcontractkit/chainlink-brownie-contracts@latest
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
forge install zk-kit/zk-kit
forge install semaphore-protocol/semaphore
```

## Deploy

This will deploy to a local node by default. You'll need to have it running in another terminal.

```bash
make deploy
```

## Deploy to Other Networks

[See below](#deploy-to-testnet-or-mainnet)

## Testing

Run the full test suite:

```bash
forge test
```

Run fork tests:

```bash
forge test --fork-url $SEPOLIA_RPC_URL
```

## Test Coverage

```bash
forge coverage
```

# Deploy to Testnet or Mainnet

1. Set up environment variables

You'll need to add the following environment variables to your `.env` file:

- `PRIVATE_KEY`: Your account private key (for development only)
- `SEPOLIA_RPC_URL`: Sepolia testnet RPC URL
- `ETHERSCAN_API_KEY`: For contract verification (optional)

2. Get testnet ETH

Visit [faucets.chain.link](https://faucets.chain.link) to get testnet ETH.

3. Deploy to Sepolia testnet

```bash
make deploy ARGS="--network sepolia"
```

## Scripts
After deploying to testnet or localnet, you can run scripts.

Example using cast with local deployment:
1. Get some WETH
```
cast send 0x694AA1769357215DE4FAC081bf1f309aDC325306 "deposit()" --value 0.1ether --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```
2. Approve WETH
```
cast send 0x694AA1769357215DE4FAC081bf1f309aDC325306 "approve(address,uint256)" 0xD6982Cf3f4268586367Afe7dc2a4FE1ba0334fFB 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY"
```
3. Deposit and mint DSC
```
cast send 0xD6982Cf3f4268586367Afe7dc2a4FE1ba0334fFB "depositCollateralAndMintDsc(address,uint256,uint256)" 0x694AA1769357215DE4FAC081bf1f309aDC325306 100000000000000000 10000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

## Estimate Gas
You can estimate gas costs by running:
```
forge snapshot
```
You'll see an output file named `.gas-snapshot`

# Formatting

```bash
forge fmt
```

# Contributing

Issues and Pull Requests are welcome!

## Development Roadmap

- Implement complete Circom ZK circuits
- Add frontend interface
- Security audit
- Mainnet deployment

# Thank You!

Thank you for your interest in ZK Privacy DeFi! This project demonstrates the perfect combination of traditional finance and cutting-edge cryptography.

---

This version maintains all the original structure and information while being fully in English. The technical terms and commands remain unchanged for accuracy.