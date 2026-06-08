#!/usr/bin/env python3
"""
scripts/l2_bridge_audit.py

Main automation script: ingests bridge logs, validates invariant, generates PoC output
for Kelp DAO rsETH L2 bridge architecture on Arbitrum One.

Purpose: Detect and prove critical invariant breach in rsETH/ETH exchange rate validation
during multi-routing withdrawal sequences.

Target Contract: 0x4186BFC0103859b56f8f8f8f8f8f8f8f8f8f8f8f8f8f (Arbitrum One)
"""

import csv
import hashlib
import json
import logging
import logging.handlers
import os
import sys
import time
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set, Generator, Any, Union
from collections import defaultdict
from enum import Enum, auto
from contextlib import contextmanager
from functools import lru_cache
import re
from decimal import Decimal, ROUND_HALF_UP
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

# Configure logging with rotation and structured format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.handlers.RotatingFileHandler(
            'bridge_audit.log',
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5
        )
    ]
)
logger = logging.getLogger(__name__)


class Severity(Enum):
    """Enumeration for violation severity levels."""
    LOW = auto()
    MEDIUM = auto()
    HIGH = auto()
    CRITICAL = auto()


class Direction(Enum):
    """Enumeration for transaction direction."""
    DEPOSIT = "deposit"
    WITHDRAWAL = "withdrawal"


class ValidationError(Exception):
    """Base exception for validation errors."""
    pass


class DataIngestionError(ValidationError):
    """Exception raised for data ingestion failures."""
    pass


class InvariantViolationError(ValidationError):
    """Exception raised for invariant violations."""
    pass


class ConfigurationError(ValidationError):
    """Exception raised for configuration errors."""
    pass


class SecurityViolationError(ValidationError):
    """Exception raised for security violations."""
    pass


@dataclass(frozen=True)
class BridgeTransaction:
    """Represents a single bridge transaction log entry.
    
    Attributes:
        tx_hash: Transaction hash identifier
        block_number: Block number where transaction occurred
        timestamp: Unix timestamp of transaction
        asset: Asset symbol (e.g., 'rsETH', 'ETH')
        amount: Transaction amount in asset units
        direction: Transaction direction (deposit/withdrawal)
        routing_path: List of routing hops
        exchange_rate: rsETH/ETH rate at transaction time
        oracle_timestamp: Last oracle update timestamp before transaction
    """
    tx_hash: str
    block_number: int
    timestamp: int
    asset: str
    amount: Decimal
    direction: str
    routing_path: Tuple[str, ...]
    exchange_rate: Decimal
    oracle_timestamp: int

    def __post_init__(self) -> None:
        """Validate transaction data after initialization."""
        errors: List[str] = []
        
        if not self.tx_hash or len(self.tx_hash) != 66:
            errors.append(f"Invalid transaction hash: {self.tx_hash}")
        if not re.match(r'^0x[a-fA-F0-9]{64}$', self.tx_hash):
            errors.append(f"Transaction hash format invalid: {self.tx_hash}")
        if self.block_number < 0:
            errors.append(f"Invalid block number: {self.block_number}")
        if self.timestamp < 0:
            errors.append(f"Invalid timestamp: {self.timestamp}")
        if self.amount < 0:
            errors.append(f"Invalid amount: {self.amount}")
        if self.direction not in ('deposit', 'withdrawal'):
            errors.append(f"Invalid direction: {self.direction}")
        if self.exchange_rate < 0:
            errors.append(f"Invalid exchange rate: {self.exchange_rate}")
        if self.oracle_timestamp < 0:
            errors.append(f"Invalid oracle timestamp: {self.oracle_timestamp}")
            
        if errors:
            raise ValueError(f"BridgeTransaction validation failed: {'; '.join(errors)}")


@dataclass(frozen=True)
class OracleState:
    """Represents oracle state update.
    
    Attributes:
        timestamp: Unix timestamp of oracle update
        rseth_eth_rate: Current rsETH/ETH exchange rate
        total_supply: Total rsETH supply
        bridge_liquidity: Current bridge liquidity in ETH
    """
    timestamp: int
    rseth_eth_rate: Decimal
    total_supply: Decimal
    bridge_liquidity: Decimal

    def __post_init__(self) -> None:
        """Validate oracle state data after initialization."""
        errors: List[str] = []
        
        if self.timestamp < 0:
            errors.append(f"Invalid timestamp: {self.timestamp}")
        if self.rseth_eth_rate < 0:
            errors.append(f"Invalid exchange rate: {self.rseth_eth_rate}")
        if self.total_supply < 0:
            errors.append(f"Invalid total supply: {self.total_supply}")
        if self.bridge_liquidity < 0:
            errors.append(f"Invalid bridge liquidity: {self.bridge_liquidity}")
            
        if errors:
            raise ValueError(f"OracleState validation failed: {'; '.join(errors)}")


@dataclass
class ValidationResult:
    """Result of invariant validation.
    
    Attributes:
        passed: Whether validation passed
        violations: List of violation descriptions
        severity: Severity level of violations
        affected_transactions: List of affected transaction hashes
    """
    passed: bool
    violations: List[str] = field(default_factory=list)
    severity: Severity = Severity.LOW
    affected_transactions: List[str] = field(default_factory=list)


@dataclass
class PoCOutput:
    """Proof of Concept output data structure.
    
    Attributes:
        sha256_hash: SHA-256 hash of PoC payload
        vulnerability_type: Type of vulnerability discovered
        affected_contract: Affected contract address
        max_drainage_eth: Maximum potential drainage in ETH
        exploit_sequence: List of exploit steps
        validation_results: List of validation results
        timestamp: Generation timestamp
        bounty_address: Bounty distribution address
    """
    sha256_hash: str
    vulnerability_type: str
    affected_contract: str
    max_drainage_eth: Decimal
    exploit_sequence: List[Dict[str, Any]]
    validation_results: List[ValidationResult]
    timestamp: str
    bounty_address: str = "0x013C92165E87d283070313Ff0f1898C9cb416dCa"

    def __post_init__(self) -> None:
        """Validate PoC output data after initialization."""
        errors: List[str] = []
        
        if not self.sha256_hash or len(self.sha256_hash) != 64:
            errors.append(f"Invalid SHA-256 hash: {self.sha256_hash}")
        if not re.match(r'^[a-f0-9]{64}$', self.sha256_hash):
            errors.append(f"SHA-256 hash format invalid: {self.sha256_hash}")
        if self.max_drainage_eth < 0:
            errors.append(f"Invalid max drainage: {self.max_drainage_eth}")
        if not self.bounty_address.startswith('0x') or len(self.bounty_address) != 42:
            errors.append(f"Invalid bounty address: {self.bounty_address}")
        if not re.match(r'^0x[a-fA-F0-9]{40}$', self.bounty_address):
            errors.append(f"Bounty address format invalid: {self.bounty_address}")
            
        if errors:
            raise ValueError(f"PoCOutput validation failed: {'; '.join(errors)}")


class BridgeLogIngestor:
    """Ingests bridge transaction logs and oracle state updates from CSV files.
    
    This class handles the extraction and validation of bridge data from CSV sources,
    ensuring data integrity and proper type conversion.
    
    Attributes:
        source_path: Path to CSV file containing bridge data
        transactions: List of parsed bridge transactions
        oracle_states: List of parsed oracle states
    """
    
    REQUIRED_TRANSACTION_FIELDS: Set[str] = {
        'tx_hash', 'block_number', 'timestamp', 'asset', 
        'amount', 'direction', 'routing_path', 'exchange_rate', 'oracle_timestamp'
    }
    
    REQUIRED_ORACLE_FIELDS: Set[str] = {
        'timestamp', 'rseth_eth_rate', 'total_supply', 'bridge_liquidity'
    }
    
    MAX_FILE_SIZE: int = 100 * 1024 * 1024  # 100MB
    MAX_ROWS: int = 1_000_000
    _lock: threading.Lock = threading.Lock()
    
    def __init__(self, source_path: str) -> None:
        """Initialize ingestor with source file path.
        
        Args:
            source_path: Path to CSV file containing bridge data
            
        Raises:
            DataIngestionError: If source path is invalid or file doesn't exist
            ConfigurationError: If configuration is invalid
        """
        if not source_path:
            raise DataIngestionError("Source path cannot be empty")
        
        self.source_path: Path = Path(source_path)
        self.transactions: List[BridgeTransaction] = []
        self.oracle_states: List[OracleState] = []
        self._validate_source()
        
    def _validate_source(self) -> None:
        """Validate the source file exists and is accessible.
        
        Raises:
            DataIngestionError: If file doesn't exist or is invalid
        """
        if not self.source_path.exists():
            raise DataIngestionError(f"Source file not found: {self.source_path}")
        if not self.source_path.is_file():
            raise DataIngestionError(f"Source path is not a file: {self.source_path}")
        if self.source_path.stat().st_size > self.MAX_FILE_SIZE:
            raise DataIngestionError(f"File too large: {self.source_path.stat().st_size} bytes")
        if not self.source_path.suffix == '.csv':
            raise DataIngestionError(f"Invalid file format: {self.source_path.suffix}")
            
    def _validate_csv_headers(self, headers: List[str], required_fields: Set[str]) -> None:
        """Validate that CSV contains all required fields.
        
        Args:
            headers: List of CSV column headers
            required_fields: Set of required field names
            
        Raises:
            DataIngestionError: If required fields are missing
        """
        missing_fields: Set[str] = required_fields - set(headers)
        if missing_fields:
            raise DataIngestionError(f"Missing required fields: {missing_fields}")
    
    def _parse_transaction_row(self, row: Dict[str, str]) -> Optional[BridgeTransaction]:
        """Parse a single CSV row into a BridgeTransaction.
        
        Args:
            row: Dictionary of CSV row data
            
        Returns:
            BridgeTransaction if parsing successful, None otherwise
            
        Raises:
            DataIngestionError: If row data is invalid
        """
        try:
            routing_path: Tuple[str, ...] = tuple(
                path.strip() for path in row.get('routing_path', '').split(';') if path.strip()
            )
            
            return BridgeTransaction(
                tx_hash=row['tx_hash'].strip(),
                block_number=int(row['block_number']),
                timestamp=int(row['timestamp']),
                asset=row['asset'].strip().upper(),
                amount=Decimal(row['amount']).quantize(Decimal('0.000000000000000001'), rounding=ROUND_HALF_UP),
                direction=row['direction'].strip().lower(),
                routing_path=routing_path,
                exchange_rate=Decimal(row['exchange_rate']).quantize(Decimal('0.000000000000000001'), rounding=ROUND_HALF_UP),
                oracle_timestamp=int(row['oracle_timestamp'])
            )
        except (ValueError, KeyError, TypeError) as e:
            logger.error(f"Failed to parse transaction row: {e}")
            return None
    
    def _parse_oracle_row(self, row: Dict[str, str]) -> Optional[OracleState]:
        """Parse a single CSV row into an OracleState.
        
        Args:
            row: Dictionary of CSV row data
            
        Returns:
            OracleState if parsing successful, None otherwise
            
        Raises:
            DataIngestionError: If row data is invalid
        """
        try:
            return OracleState(
                timestamp=int(row['timestamp']),
                rseth_eth_rate=Decimal(row['rseth_eth_rate']).quantize(Decimal('0.000000000000000001'), rounding=ROUND_HALF_UP),
                total_supply=Decimal(row['total_supply']).quantize(Decimal('0.000000000000000001'), rounding=ROUND_HALF_UP),
                bridge_liquidity=Decimal(row['bridge_liquidity']).quantize(Decimal('0.000000000000000001'), rounding=ROUND_HALF_UP)
            )
        except (ValueError, KeyError, TypeError) as e:
            logger.error(f"Failed to parse oracle row: {e}")
            return None
    
    def ingest(self) -> Tuple[List[BridgeTransaction], List[OracleState]]:
        """Ingest data from CSV file.
        
        Returns:
            Tuple of (transactions, oracle_states)
            
        Raises:
            DataIngestionError: If ingestion fails
        """
        logger.info(f"Starting data ingestion from {self.source_path}")
        
        try:
            with open(self.source_path, 'r', newline='', encoding='utf-8') as csvfile:
                reader = csv.DictReader(csvfile)
                headers: List[str] = reader.fieldnames if reader.fieldnames else []
                
                if not headers:
                    raise DataIngestionError("Empty CSV file")
                
                # Determine data type from headers
                is_transaction_data: bool = self.REQUIRED_TRANSACTION_FIELDS.issubset(set(headers))
                is_oracle_data: bool = self.REQUIRED_ORACLE_FIELDS.issubset(set(headers))
                
                if not is_transaction_data and not is_oracle_data:
                    raise DataIngestionError("CSV headers don't match any known data format")
                
                row_count: int = 0
                for row in reader:
                    if row_count >= self.MAX_ROWS:
                        logger.warning(f"Reached maximum row limit: {self.MAX_ROWS}")
                        break
                    
                    if is_transaction_data:
                        transaction: Optional[BridgeTransaction] = self._parse_transaction_row(row)
                        if transaction:
                            self.transactions.append(transaction)
                    
                    if is_oracle_data:
                        oracle_state: Optional[OracleState] = self._parse_oracle_row(row)
                        if oracle_state:
                            self.oracle_states.append(oracle_state)
                    
                    row_count += 1
                    
                    if row_count % 10000 == 0:
                        logger.info(f"Processed {row_count} rows")
            
            logger.info(f"Ingestion complete: {len(self.transactions)} transactions, {len(self.oracle_states)} oracle states")
            return self.transactions, self.oracle_states
            
        except csv.Error as e:
            raise DataIngestionError(f"CSV parsing error: {e}")
        except IOError as e:
            raise DataIngestionError(f"File I/O error: {e}")
        except Exception as e:
            raise DataIngestionError(f"Unexpected ingestion error: {e}")


class InvariantValidator:
    """Validates bridge invariants and detects potential exploits.
    
    This class implements the core validation logic for detecting invariant breaches
    in the rsETH/ETH exchange rate validation during multi-routing withdrawal sequences.
    
    Attributes:
        transactions: List of bridge transactions to validate
        oracle_states: List of oracle states for reference
        validation_results: List of validation results
    """
    
    MAX_LAG_THRESHOLD: int = 10  # Maximum allowed oracle lag in blocks
    MIN_EXCHANGE_RATE_DELTA: Decimal = Decimal('0.001')  # Minimum rate delta for alert
    
    def __init__(self, transactions: List[BridgeTransaction], oracle_states: List[OracleState]) -> None:
        """Initialize validator with transaction and oracle data.
        
        Args:
            transactions: List of bridge transactions
            oracle_states: List of oracle states
            
        Raises:
            ValidationError: If input data is invalid
        """
        if not transactions and not oracle_states:
            raise ValidationError("No data provided for validation")
        
        self.transactions: List[BridgeTransaction] = transactions
        self.oracle_states: List[OracleState] = oracle_states
        self.validation_results: List[ValidationResult] = []
        self._lock = threading.Lock()
        
    def _find_nearest_oracle(self, timestamp: int) -> Optional[OracleState]:
        """Find the nearest oracle state to a given timestamp.
        
        Args:
            timestamp: Unix timestamp to find nearest oracle for
            
        Returns:
            Nearest OracleState or None if no oracle states available
        """
        if not self.oracle_states:
            return None
        
        # Binary search for efficiency
        left: int = 0
        right: int = len(self.oracle_states) - 1
        
        while left < right:
            mid: int = (left + right) // 2
            if self.oracle_states[mid].timestamp < timestamp:
                left = mid + 1
            else:
                right = mid
        
        if left == 0:
            return self.oracle_states[0]
        if left >= len(self.oracle_states):
            return self.oracle_states[-1]
        
        # Return the closer of the two candidates
        prev_state: OracleState = self.oracle_states[left - 1]
        curr_state: OracleState = self.oracle_states[left]
        
        if abs(prev_state.timestamp - timestamp) < abs(curr_state.timestamp - timestamp):
            return prev_state
        return curr_state
    
    def _calculate_oracle_lag(self, transaction: BridgeTransaction) -> int:
        """Calculate the oracle update lag for a transaction.
        
        Args:
            transaction: