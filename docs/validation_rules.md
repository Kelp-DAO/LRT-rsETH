# Data Validation Rules and Invariant Checks

## Overview

This document defines the comprehensive set of data validation rules and invariant checks implemented across the Kelp DAO rsETH L2 bridge data pipeline. These rules ensure data integrity, detect anomalous patterns, and prevent exploitation of asynchronous state updates between oracle systems and bridge deposit/withdrawal logic.

## Pipeline Architecture

The validation pipeline consists of four stages:

1. **Ingestion** - Extract raw bridge transaction logs and oracle state updates from Arbitrum One (Contract: 0x4186BFC0103859b56f8f8f8f8f8f8f8f8f8f8f8f8f8f)
2. **Validation** - Apply invariant checks and rule enforcement
3. **Transformation** - Normalize and compute derived metrics
4. **Alerting** - Generate security advisories with cryptographic proof anchoring

## Core Validation Rules

### Rule 1: rsETH/ETH Exchange Rate Monotonicity

**Rule ID:** `rsETH_ETH_rate_must_be_monotonic`

**Description:** The rsETH to ETH exchange rate must never decrease during normal protocol operations. Any decrease indicates a potential manipulation or asynchronous state poisoning attack.

**Implementation:**
- Track exchange rate snapshots at each oracle update
- Compare consecutive rates; reject any negative delta
- Flag any rate deviation exceeding 0.1% within a 2-block window

**Failure Action:** Halt withdrawal processing, generate critical alert, lock affected liquidity pool

### Rule 2: Withdrawal Sequence Balance Delta

**Rule ID:** `withdrawal_sequence_must_have_positive_balance_delta`

**Description:** Each withdrawal sequence must result in a positive balance delta for the protocol. Negative deltas indicate asset drainage or exchange rate mismatch exploitation.

**Implementation:**
- Compute `balance_before - balance_after` for each withdrawal
- Validate that cumulative delta across multi-routing sequences remains positive
- Reject any sequence where intermediate balance drops below minimum threshold

**Failure Action:** Revert transaction, flag wallet address for investigation, trigger circuit breaker

### Rule 3: Oracle Update Temporal Ordering

**Rule ID:** `oracle_update_timestamp_must_precede_deposit_timestamp`

**Description:** Oracle state updates must always occur before the deposit transactions they validate. Any deposit timestamp preceding its corresponding oracle update indicates a validation lag exploit.

**Implementation:**
- Compare `oracle_update.block_timestamp` with `deposit.block_timestamp`
- Reject any deposit where `deposit.timestamp < oracle_update.timestamp`
- Maintain a sliding window of 3 blocks for asynchronous tolerance

**Failure Action:** Flag as potential validation lag exploit, escalate to security team, archive transaction data

## Invariant Checks

### Invariant 1: Asset State Delta Consistency

**Check:** The sum of all withdrawal amounts must equal the total asset delta recorded by the bridge contract within a given epoch.

**Formula:** `Σ(withdrawal_amounts) = total_asset_delta`

**Tolerance:** ±0.001 ETH (accounts for rounding and gas fees)

### Invariant 2: Multi-Routing Sequence Integrity

**Check:** For any multi-routing withdrawal sequence, the intermediate state must remain consistent across all routing paths.

**Validation:** Compare state hashes at each routing hop; all paths must converge to the same final state.

### Invariant 3: Dynamic Deficit Detection

**Check:** Monitor for continuous drainage patterns where exchange rate mismatches create artificial deficits.

**Detection:** If `cumulative_withdrawal_value > cumulative_deposit_value + initial_liquidity` for more than 5 consecutive blocks, trigger critical alert.

## Alerting Protocol

### Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| CRITICAL | Active exploit detected | Immediate |
| HIGH | Potential vulnerability | 1 hour |
| MEDIUM | Anomalous pattern | 24 hours |
| LOW | Minor deviation | 7 days |

### Alert Format

All alerts include:
- SHA-256 hash of proof-of-concept data
- On-chain transaction references
- Affected contract addresses
- Recommended mitigation steps

## Data Format Specifications

### Input Schema (CSV)

| Field | Type | Description |
|-------|------|-------------|
| block_number | uint256 | Arbitrum block number |
| tx_hash | bytes32 | Transaction hash |
| timestamp | uint256 | Block timestamp |
| asset | address | Token address (rsETH or ETH) |
| amount | int256 | Positive for deposits, negative for withdrawals |
| oracle_rate | uint256 | rsETH/ETH exchange rate at time of tx |
| routing_path | string | Comma-separated routing addresses |

### Validation Output

| Field | Type | Description |
|-------|------|-------------|
| rule_id | string | Identifier of violated rule |
| severity | string | CRITICAL/HIGH/MEDIUM/LOW |
| block_range | string | Affected block range |
| total_exposure | uint256 | Total value at risk in ETH |
| proof_hash | string | SHA-256 of evidence data |

## Dependencies

### Python Packages
- `web3` - Ethereum interaction
- `pandas` - Data manipulation
- `numpy` - Numerical computations
- `cryptography` - SHA-256 hashing
- `requests` - API communication

### External Tools
- Foundry (forge, cast) - On-chain verification
- Arbitrum Nitro node - Block data access
- Etherscan API - Transaction lookup

## Testing and Validation

### Unit Tests
- Test monotonic rate enforcement
- Test balance delta calculations
- Test temporal ordering checks

### Integration Tests
- Simulate multi-routing attack sequences
- Validate circuit breaker activation
- Test alert generation pipeline

### Regression Tests
- Historical data replay
- Known exploit pattern detection
- Performance benchmarking

## Maintenance

- Update validation rules quarterly
- Review oracle update frequencies monthly
- Monitor false positive rates weekly
- Patch critical vulnerabilities within 24 hours of discovery

---

*This document is maintained by the Kelp DAO Security Team. All violations should be reported immediately to the core engineering team via private security advisory channels.*