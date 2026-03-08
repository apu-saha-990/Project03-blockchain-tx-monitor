"""Shared pytest fixtures."""

from __future__ import annotations

import pytest


@pytest.fixture
def sample_eth_tx_payload() -> dict:
    return {
        "hash": "0xabc123def456abc123def456abc123def456abc123def456abc123def456abc1",
        "from": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        "to": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        "value": "0xde0b6b3a7640000",   # 1 ETH in wei
        "gasPrice": "0x2540be400",        # 10 Gwei
        "gas": "0x5208",
        "input": "0x",
        "nonce": "0x1a",
    }


@pytest.fixture
def sample_block_payload() -> dict:
    return {
        "number": "0x12a05f2",
        "hash": "0xblock123",
        "parentHash": "0xparent456",
        "gasUsed": "0xf4240",
        "gasLimit": "0x1c9c380",
        "baseFeePerGas": "0x12a05f200",
        "miner": "0xminer000",
        "transactions": ["0xtx1", "0xtx2", "0xtx3"],
    }
