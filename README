# Decentralized Stablecoin (DSC)

A minimal, exogenously collateralized, USD-pegged stablecoin protocol built with Solidity and Foundry.

## Overview

The Decentralized Stablecoin (DSC) project is a decentralized finance (DeFi) protocol inspired by MakerDAO's Dai Stablecoin System (DSS). Its goal is to maintain a **1 DSC = $1 target peg** through overcollateralization, smart-contract-enforced minting rules, and collateral liquidation.

The system allows users to deposit supported crypto assets as collateral and mint DSC against their collateralized positions. Users can burn DSC to repay their debt and redeem eligible collateral.

The protocol is designed to remain minimal, with no protocol governance or minting fees in its intended design.

## Core Principles

- **Exogenously Collateralized:** DSC is backed by external crypto assets rather than relying solely on its own token economics.
- **USD-Pegged:** The target value is 1 DSC = $1.
- **Algorithmically Stabilized:** Smart contracts enforce collateralization requirements and liquidation rules.
- **Overcollateralized:** Users must maintain sufficient collateral value relative to the DSC they mint.
- **Permissionless Access:** Users can interact with the protocol through its smart contracts, subject to the implemented rules.

## Supported Collateral

The intended design uses:

- **WETH (Wrapped Ether)**
- **WBTC (Wrapped Bitcoin)**

Collateral prices are obtained through Chainlink price feeds. The collateral tokens and corresponding price-feed addresses are supplied to the engine during deployment.

## How It Works

### 1. Deposit Collateral

Users deposit supported collateral through `depositCollateral()`. The engine records each user's collateral balance and transfers the specified tokens into the protocol.

### 2. Mint DSC

Users call `mintDSC()` to mint DSC against their collateral. The engine updates the user's debt and checks the health factor before authorizing token issuance.

### 3. Redeem Collateral

Users can call `reedemCollateral()` to withdraw eligible collateral. The engine checks the user's health factor after the withdrawal to prevent an unsafe resulting position.

### 4. Burn DSC

Users can burn DSC to reduce their outstanding debt. The `reedemCollateralForDSC()` function combines debt repayment and collateral redemption into one operation.

### 5. Liquidate Unsafe Positions

The `liquidate()` function allows a liquidator to repay part of an unhealthy user's DSC debt and receive collateral with a liquidation bonus.

This mechanism is designed to help maintain protocol solvency when collateral prices decline.

## Health Factor

The health factor measures the safety of a user's collateralized position.

The protocol calculates it using the collateral value, liquidation threshold, and outstanding DSC debt.

**Formula:**

\[
HF=\frac{C\times LT}{D}
\]

Where:

- \(HF\) = Health factor
- \(C\) = Total collateral value in USD
- \(LT\) = Liquidation threshold
- \(D\) = Outstanding DSC debt in USD

The current engine defines a liquidation threshold of 50% and a minimum health factor of 1, using the contract's configured precision.

- **HF greater than 1:** The position is above the liquidation boundary.
- **HF equal to 1:** The position is at the liquidation boundary.
- **HF below 1:** The position is eligible for liquidation under the intended rules.

## Liquidation Parameters

The engine currently defines the following parameters:

| Parameter | Value |
|---|---:|
| Liquidation threshold | 50% |
| Liquidation bonus | 10% |
| Minimum health factor | 1 |
| Precision | \(10^{18}\) |

The liquidation bonus is an incentive for liquidators to repay debt on behalf of users whose positions have become unsafe.

## Smart Contract Architecture

### `DSCEngine.sol`

The core protocol contract. It manages collateral deposits and redemptions, DSC minting and burning, collateral valuation, health-factor checks, and liquidations.

### `DecentralizedStableCoin.sol`

The DSC token contract responsible for the stablecoin's ERC-20 functionality and authorized minting and burning operations.

### `OracleLib.sol`

The oracle utility library imported by the engine to support price-feed handling. The engine also uses Chainlink's `AggregatorV3Interface` to retrieve collateral prices.

## Technology Stack

- **Solidity** — Smart contract development
- **Foundry** — Compilation, testing, deployment, and debugging
- **OpenZeppelin** — ERC-20 interfaces and `ReentrancyGuard`
- **Chainlink** — Collateral price feeds
- **Ethereum / EVM-compatible networks** — Potential deployment environments

## Getting Started

### Prerequisites

Install the following tools:

- Git
- Foundry
- A compatible Solidity development environment

### Installation

Clone the repository:

```bash
git clone https://github.com/therealWiliiam/defi-stablecoin-project-2026.git
cd <your-project-directory>
```

Install the project's dependencies:

```bash
forge install
```

Compile the contracts:

```bash
forge build
```

Run the test suite:

```bash
forge test
```

**Note:** Replace the repository URL and directory placeholder with your actual project details. Ensure the required dependencies and Foundry configuration are set up before running these commands.

## Security Considerations

This project is intended for educational purposes and portfolio demonstration.

Before deployment to a production environment, the protocol requires thorough testing and review of:

- Collateral transfer and accounting logic
- Health-factor calculations and zero-debt handling
- Chainlink price-feed validity and stale-price protection
- Liquidation calculations, incentives, and edge cases
- Minting permissions and token supply accounting
- Reentrancy protection and external contract interactions

The current implementation should be reviewed and tested carefully before being treated as production-ready.

## Disclaimer

This repository is an independent educational project inspired by established decentralized stablecoin designs. It is not affiliated with or endorsed by MakerDAO, Chainlink, or OpenZeppelin.

DSC's $1 peg is a target rather than a guarantee. Smart-contract bugs, collateral price volatility, oracle failures, and insufficient market liquidity can affect the protocol's stability.

Use at your own risk. This project is not financial advice.
