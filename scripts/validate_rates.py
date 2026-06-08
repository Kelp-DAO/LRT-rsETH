#!/usr/bin/env python3
"""
scripts/validate_rates.py

Validates rsETH/ETH exchange rate monotonicity and detects poisoning patterns
in the Kelp DAO rsETH L2 bridge architecture on Arbitrum One.

This script implements the validation stage of the data pipeline, checking:
- rsETH/ETH rate monotonicity
- Withdrawal sequence positive balance deltas
- Oracle update timestamp precedence over deposit timestamps
"""

import hashlib
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple, Set, Iterator, Any, Union
from pathlib import Path
import csv
import json
import sys
import os
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
from functools import lru_cache
from contextlib import contextmanager
import threading
from enum import Enum, auto
from abc import ABC, abstractmethod
import traceback
from collections import defaultdict, deque
import time


# Configure logging with structured format
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s - %(filename)s:%(lineno)d',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('bridge_validation.log')
    ]
)
logger = logging.getLogger(__name__)


class TransactionType(Enum):
    """Enum for transaction types."""
    DEPOSIT = auto()
    WITHDRAWAL = auto()
    
    @classmethod
    def from_string(cls, value: str) -> 'TransactionType':
        """Convert string to TransactionType enum.
        
        Args:
            value: String representation of transaction type
            
        Returns:
            Corresponding TransactionType enum value
            
        Raises:
            ValueError: If value is not a valid transaction type
        """
        if not isinstance(value, str):
            raise TypeError(f"Expected string, got {type(value)}")
        
        try:
            return cls[value.upper().strip()]
        except KeyError:
            valid_types = [t.name.lower() for t in TransactionType]
            raise ValueError(
                f"Invalid transaction type: '{value}'. Must be one of: {valid_types}"
            )


class ValidationError(Exception):
    """Base exception for validation errors."""
    pass


class DataLoadError(ValidationError):
    """Exception raised when data loading fails."""
    pass


class MonotonicityBreachError(ValidationError):
    """Exception raised when monotonicity breach is detected."""
    pass


class NegativeDeltaError(ValidationError):
    """Exception raised when negative delta is detected."""
    pass


class OracleTimestampViolationError(ValidationError):
    """Exception raised when oracle timestamp violation is detected."""
    pass


class SecurityViolationError(ValidationError):
    """Exception raised when security violation is detected."""
    pass


@dataclass(frozen=True)
class BridgeTransaction:
    """Represents a bridge transaction record with immutable fields."""
    tx_hash: str
    timestamp: datetime
    block_number: int
    asset: str
    amount: Decimal
    tx_type: TransactionType
    exchange_rate: Decimal
    oracle_timestamp: Optional[datetime] = None
    sequence_id: Optional[int] = None
    
    def __post_init__(self) -> None:
        """Validate transaction data after initialization."""
        errors: List[str] = []
        
        # Validate transaction hash
        if not self.tx_hash or not isinstance(self.tx_hash, str):
            errors.append(f"Invalid transaction hash: {self.tx_hash}")
        elif len(self.tx_hash) != 64:
            errors.append(f"Transaction hash length must be 64, got {len(self.tx_hash)}")
        elif not all(c in '0123456789abcdef' for c in self.tx_hash.lower()):
            errors.append(f"Transaction hash contains invalid characters: {self.tx_hash}")
        
        # Validate block number
        if not isinstance(self.block_number, int):
            errors.append(f"Block number must be integer, got {type(self.block_number)}")
        elif self.block_number <= 0:
            errors.append(f"Invalid block number: {self.block_number}")
        
        # Validate amount
        if not isinstance(self.amount, Decimal):
            errors.append(f"Amount must be Decimal, got {type(self.amount)}")
        elif self.amount <= Decimal('0'):
            errors.append(f"Invalid amount: {self.amount}")
        
        # Validate exchange rate
        if not isinstance(self.exchange_rate, Decimal):
            errors.append(f"Exchange rate must be Decimal, got {type(self.exchange_rate)}")
        elif self.exchange_rate <= Decimal('0'):
            errors.append(f"Invalid exchange rate: {self.exchange_rate}")
        
        # Validate timestamps
        if not isinstance(self.timestamp, datetime):
            errors.append(f"Timestamp must be datetime, got {type(self.timestamp)}")
        else:
            object.__setattr__(self, 'timestamp', 
                              self._ensure_utc(self.timestamp))
        
        if self.oracle_timestamp is not None:
            if not isinstance(self.oracle_timestamp, datetime):
                errors.append(f"Oracle timestamp must be datetime, got {type(self.oracle_timestamp)}")
            else:
                object.__setattr__(self, 'oracle_timestamp', 
                                  self._ensure_utc(self.oracle_timestamp))
        
        if errors:
            raise ValueError(f"BridgeTransaction validation failed: {'; '.join(errors)}")
    
    @staticmethod
    def _ensure_utc(dt: datetime) -> datetime:
        """Ensure datetime is timezone-aware UTC.
        
        Args:
            dt: Datetime object to normalize
            
        Returns:
            Timezone-aware UTC datetime
        """
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)


@dataclass
class ValidationResult:
    """Stores validation results for a set of transactions."""
    is_valid: bool = True
    monotonicity_breaches: List[Dict[str, Any]] = field(default_factory=list)
    negative_delta_sequences: List[Dict[str, Any]] = field(default_factory=list)
    oracle_timestamp_violations: List[Dict[str, Any]] = field(default_factory=list)
    poisoning_patterns: List[Dict[str, Any]] = field(default_factory=list)
    total_eth_at_risk: Decimal = Decimal('0.0')
    validation_timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    validation_duration_ms: float = 0.0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert validation result to dictionary.
        
        Returns:
            Dictionary representation of validation result
        """
        return {
            'is_valid': self.is_valid,
            'monotonicity_breaches': self.monotonicity_breaches,
            'negative_delta_sequences': self.negative_delta_sequences,
            'oracle_timestamp_violations': self.oracle_timestamp_violations,
            'poisoning_patterns': self.poisoning_patterns,
            'total_eth_at_risk': str(self.total_eth_at_risk),
            'validation_timestamp': self.validation_timestamp.isoformat(),
            'validation_duration_ms': self.validation_duration_ms
        }
    
    def merge(self, other: 'ValidationResult') -> None:
        """Merge another validation result into this one.
        
        Args:
            other: ValidationResult to merge
        """
        self.is_valid = self.is_valid and other.is_valid
        self.monotonicity_breaches.extend(other.monotonicity_breaches)
        self.negative_delta_sequences.extend(other.negative_delta_sequences)
        self.oracle_timestamp_violations.extend(other.oracle_timestamp_violations)
        self.poisoning_patterns.extend(other.poisoning_patterns)
        self.total_eth_at_risk += other.total_eth_at_risk


class TransactionLoader:
    """Handles loading and parsing of transaction data from various sources."""
    
    REQUIRED_FIELDS: Set[str] = {'tx_hash', 'timestamp', 'block_number', 'asset', 
                                'amount', 'tx_type', 'exchange_rate'}
    OPTIONAL_FIELDS: Set[str] = {'oracle_timestamp', 'sequence_id'}
    MAX_FILE_SIZE: int = 100 * 1024 * 1024  # 100MB
    MAX_TRANSACTIONS: int = 1_000_000
    
    @staticmethod
    def load_from_csv(file_path: str) -> List[BridgeTransaction]:
        """
        Load bridge transactions from CSV file with validation.
        
        Args:
            file_path: Path to CSV file containing transaction data
            
        Returns:
            List of validated BridgeTransaction objects
            
        Raises:
            DataLoadError: If file cannot be loaded or parsed
            FileNotFoundError: If file does not exist
            SecurityViolationError: If file size exceeds limits
        """
        start_time = time.time()
        
        try:
            file_path_obj = Path(file_path).resolve()
        except Exception as e:
            raise DataLoadError(f"Invalid file path: {e}")
        
        # Security checks
        if not file_path_obj.exists():
            raise FileNotFoundError(f"Transaction file not found: {file_path}")
        if not file_path_obj.is_file():
            raise DataLoadError(f"Path is not a file: {file_path}")
        
        file_size = file_path_obj.stat().st_size
        if file_size == 0:
            raise DataLoadError(f"Empty file: {file_path}")
        if file_size > TransactionLoader.MAX_FILE_SIZE:
            raise SecurityViolationError(
                f"File size {file_size} exceeds maximum {TransactionLoader.MAX_FILE_SIZE}"
            )
        
        transactions: List[BridgeTransaction] = []
        errors: List[str] = []
        row_count = 0
        
        try:
            with open(file_path_obj, 'r', newline='', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                
                # Validate headers
                if not reader.fieldnames:
                    raise DataLoadError("CSV file has no headers")
                
                all_fields = TransactionLoader.REQUIRED_FIELDS | TransactionLoader.OPTIONAL_FIELDS
                unknown_fields = set(reader.fieldnames) - all_fields
                if unknown_fields:
                    logger.warning(f"Unknown fields in CSV: {unknown_fields}")
                
                missing_fields = TransactionLoader.REQUIRED_FIELDS - set(reader.fieldnames)
                if missing_fields:
                    raise DataLoadError(f"Missing required fields: {missing_fields}")
                
                for row_num, row in enumerate(reader, start=2):
                    row_count += 1
                    
                    if row_count > TransactionLoader.MAX_TRANSACTIONS:
                        raise DataLoadError(
                            f"Exceeded maximum transaction limit of {TransactionLoader.MAX_TRANSACTIONS}"
                        )
                    
                    try:
                        tx = TransactionLoader._parse_row(row)
                        transactions.append(tx)
                    except (ValueError, KeyError, TypeError) as e:
                        error_msg = f"Row {row_num}: {str(e)}"
                        errors.append(error_msg)
                        logger.warning(f"Skipping invalid row: {error_msg}")
        
        except csv.Error as e:
            raise DataLoadError(f"CSV parsing error: {e}")
        except IOError as e:
            raise DataLoadError(f"File read error: {e}")
        
        if errors:
            logger.warning(f"Encountered {len(errors)} errors while loading transactions")
        
        if not transactions:
            raise DataLoadError("No valid transactions found in file")
        
        elapsed_ms = (time.time() - start_time) * 1000
        logger.info(
            f"Successfully loaded {len(transactions)} transactions from {file_path} "
            f"in {elapsed_ms:.2f}ms"
        )
        
        return transactions
    
    @staticmethod
    def _parse_row(row: Dict[str, str]) -> BridgeTransaction:
        """
        Parse a single CSV row into a BridgeTransaction.
        
        Args:
            row: Dictionary representing a CSV row
            
        Returns:
            Validated BridgeTransaction object
            
        Raises:
            ValueError: If row data is invalid
            TypeError: If row data types are incorrect
        """
        try:
            # Parse required fields
            tx_hash = row['tx_hash'].strip()
            if not tx_hash:
                raise ValueError("Empty transaction hash")
            
            timestamp = datetime.fromisoformat(row['timestamp'].strip())
            block_number = int(row['block_number'].strip())
            asset = row['asset'].strip()
            if not asset:
                raise ValueError("Empty asset field")
            
            amount = Decimal(row['amount'].strip())
            tx_type = TransactionType.from_string(row['tx_type'].strip())
            exchange_rate = Decimal(row['exchange_rate'].strip())
            
            # Parse optional fields
            oracle_timestamp: Optional[datetime] = None
            if 'oracle_timestamp' in row and row['oracle_timestamp'].strip():
                oracle_timestamp = datetime.fromisoformat(row['oracle_timestamp'].strip())
            
            sequence_id: Optional[int] = None
            if 'sequence_id' in row and row['sequence_id'].strip():
                sequence_id = int(row['sequence_id'].strip())
            
            return BridgeTransaction(
                tx_hash=tx_hash,
                timestamp=timestamp,
                block_number=block_number,
                asset=asset,
                amount=amount,
                tx_type=tx_type,
                exchange_rate=exchange_rate,
                oracle_timestamp=oracle_timestamp,
                sequence_id=sequence_id
            )
            
        except KeyError as e:
            raise ValueError(f"Missing required field: {e}")
        except ValueError as e:
            raise ValueError(f"Invalid field value: {e}")
        except InvalidOperation as e:
            raise ValueError(f"Invalid decimal value: {e}")


class RateValidator:
    """Validates rsETH/ETH exchange rate monotonicity and detects anomalies."""
    
    def __init__(self, tolerance: Decimal = Decimal('0.001')):
        """
        Initialize rate validator.
        
        Args:
            tolerance: Maximum allowed rate deviation (default 0.1%)
        """
        self.tolerance = tolerance
        self._rate_cache: Dict[str, Decimal] = {}
    
    def validate_monotonicity(
        self, 
        transactions: List[BridgeTransaction]
    ) -> List[Dict[str, Any]]:
        """
        Validate exchange rate monotonicity across transactions.
        
        Args:
            transactions: List of bridge transactions to validate
            
        Returns:
            List of monotonicity breach details
        """
        breaches: List[Dict[str, Any]] = []
        
        if not transactions:
            return breaches
        
        sorted_txs = sorted(transactions, key=lambda tx: (tx.block_number, tx.timestamp))
        prev_rate: Optional[Decimal] = None
        
        for tx in sorted_txs:
            if prev_rate is not None:
                rate_change = abs(tx.exchange_rate - prev_rate) / prev_rate
                
                if rate_change > self.tolerance:
                    breach = {
                        'tx_hash': tx.tx_hash,
                        'block_number': tx.block_number,
                        'timestamp': tx.timestamp.isoformat(),
                        'prev_rate': str(prev_rate),
                        'current_rate': str(tx.exchange_rate),
                        'rate_change_pct': float(rate_change * 100),
                        'tolerance_pct': float(self.tolerance * 100)
                    }
                    breaches.append(breach)
                    logger.warning(
                        f"Monotonicity breach detected: tx={tx.tx_hash[:16]}... "
                        f"rate_change={rate_change*100:.4f}%"
                    )
            
            prev_rate = tx.exchange_rate
        
        return breaches
    
    def validate_withdrawal_deltas(
        self,
        transactions: List[BridgeTransaction]
    ) -> List[Dict[str, Any]]:
        """
        Validate withdrawal sequence deltas are positive.
        
        Args:
            transactions: List of bridge transactions to validate
            
        Returns:
            List of negative delta sequence details
        """
        negative_deltas: List[Dict[str, Any]] = []
        
        withdrawals = [
            tx for tx in transactions 
            if tx.tx_type == TransactionType.WITHDRAWAL
        ]
        
        if not withdrawals:
            return negative_deltas
        
        sorted_withdrawals = sorted(
            withdrawals, 
            key=lambda tx: (tx.block_number, tx.timestamp)
        )
        
        for i in range(1, len(sorted_withdrawals)):
            prev_tx = sorted_withdrawals[i - 1]
            curr_tx = sorted_withdrawals[i]
            
            delta = curr_tx.amount - prev_tx.amount
            
            if delta < Decimal('0'):
                negative_delta = {
                    'prev_tx_hash': prev_tx.tx_hash,
                    'curr_tx_hash': curr_tx.tx_hash,
                    'prev_amount': str(prev_tx.amount),
                    'curr_amount': str(curr_tx.amount),
                    'delta': str(delta),
                    'block_number': curr_tx.block_number,
                    'timestamp': curr_tx.timestamp.isoformat()
                }
                negative_deltas.append(negative_delta)
                logger.warning(
                    f"Negative delta detected: {delta} ETH between "
                    f"txs {prev_tx.tx_hash[:16]}... and {curr_tx.tx_hash[:16]}..."
                )
        
        return negative_deltas
    
    def validate_oracle_timestamps(
        self,
        transactions: List[BridgeTransaction]
    ) -> List[Dict[str, Any]]:
        """
        Validate oracle timestamps precede deposit timestamps.
        
        Args:
            transactions: List of bridge transactions to validate
            
        Returns:
            List of oracle timestamp violation details
        """
        violations: List[Dict[str, Any]] = []
        
        for tx in transactions:
            if tx.oracle_timestamp is not None and tx.tx_type == TransactionType.DEPOSIT:
                if tx.oracle_timestamp > tx.timestamp:
                    violation = {
                        'tx_hash': tx.tx_hash,
                        'block_number': tx.block_number,
                        'deposit_timestamp': tx.timestamp.isoformat(),
                        'oracle_timestamp': tx.oracle_timestamp.isoformat(),
                        'time_difference_seconds': (
                            tx.oracle_timestamp - tx.timestamp
                        ).total_seconds()
                    }
                    violations.append(violation)
                    logger.warning(
                        f"Oracle timestamp violation: tx={tx.tx_hash[:16]}... "
                        f"oracle={tx.oracle_timestamp.isoformat()} > "
                        f"deposit={tx.timestamp.isoformat()}"
                    )
        
        return violations


class PoisoningPattern