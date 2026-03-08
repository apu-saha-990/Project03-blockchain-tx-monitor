"""Main entrypoint — Phase 1: live stream with ETH/USD + gas display."""

from __future__ import annotations

import asyncio
import logging
import os
from dotenv import load_dotenv

from src.ingestion.alchemy_ws import AlchemyWebSocket, RawTransaction, RawBlock
from src.ingestion.price_feed import PriceFeed

load_dotenv()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

TX_COUNT = 0
BLOCK_COUNT = 0
price_feed: PriceFeed | None = None


def on_transaction(tx: RawTransaction) -> None:
    global TX_COUNT
    TX_COUNT += 1

    value_eth = int(tx.value_hex, 16) / 1e18
    gas_price_gwei = (int(tx.gas_price_hex, 16) / 1e9) if tx.gas_price_hex else 0
    gas_limit = int(tx.gas_hex, 16) if tx.gas_hex else 0
    gas_cost_eth = (gas_limit * gas_price_gwei) / 1e9
    gas_cost_usd = price_feed.eth_to_usd(gas_cost_eth) if price_feed else "n/a"
    usd = price_feed.eth_to_usd(value_eth) if price_feed else "n/a"

    if value_eth > 0.01:  # only show txs with meaningful value
        print(
            f"[TX #{TX_COUNT:>4}] {tx.tx_hash[:12]}… | "
            f"{value_eth:>10.4f} ETH ({usd:>14}) | "
            f"fee {gas_cost_eth:.6f} ETH ({gas_cost_usd}) | {gas_price_gwei:.1f} gwei | "
            f"from {str(tx.from_address)[:12]}…"
        )


def on_block(block: RawBlock) -> None:
    global BLOCK_COUNT
    BLOCK_COUNT += 1
    print(
        f"\n[BLOCK #{block.block_number:,}] "
        f"gas used {block.gas_used:>12,} | "
        f"miner {block.miner[:12]}…\n"
    )


async def main() -> None:
    global price_feed

    ws_url = os.getenv("ALCHEMY_WS_URL")
    cmc_key = os.getenv("COINMARKETCAP_API_KEY")

    if not ws_url:
        raise ValueError("ALCHEMY_WS_URL not set in .env")

    if cmc_key:
        price_feed = PriceFeed(api_key=cmc_key)
        await price_feed.start()
    else:
        logger.warning("COINMARKETCAP_API_KEY not set — USD values will show as n/a")

    logger.info("Connecting to Alchemy — Ethereum Mainnet")

    client = AlchemyWebSocket(
        ws_url=ws_url,
        on_transaction=on_transaction,
        on_block=on_block,
    )

    try:
        await client.start()
    except KeyboardInterrupt:
        await client.stop()
        if price_feed:
            await price_feed.stop()
        logger.info("Stopped. TX seen: %d | Blocks seen: %d", TX_COUNT, BLOCK_COUNT)


if __name__ == "__main__":
    asyncio.run(main())
