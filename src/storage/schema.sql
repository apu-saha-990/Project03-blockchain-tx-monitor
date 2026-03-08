-- ── Extensions ──────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ── Transactions ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transactions (
    id              BIGSERIAL,
    ts              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    chain           TEXT        NOT NULL,          -- 'ethereum' | 'bitcoin'
    tx_hash         TEXT        NOT NULL,
    block_number    BIGINT,                        -- NULL if still in mempool
    from_address    TEXT,
    to_address      TEXT,
    value_wei       NUMERIC(40, 0),               -- ETH: wei, BTC: satoshis
    gas_price_wei   NUMERIC(40, 0),
    gas_limit       BIGINT,
    gas_used        BIGINT,
    is_contract     BOOLEAN     DEFAULT FALSE,
    contract_type   TEXT,                          -- 'erc20' | 'erc721' | 'dex' | NULL
    status          TEXT        DEFAULT 'pending', -- 'pending' | 'confirmed' | 'dropped'
    mempool_age_ms  INTEGER,
    raw_data        JSONB,
    PRIMARY KEY (ts, id)
);

SELECT create_hypertable('transactions', 'ts', if_not_exists => TRUE);
SELECT add_retention_policy('transactions', INTERVAL '30 days', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS idx_transactions_hash   ON transactions (tx_hash, ts DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_from   ON transactions (from_address, ts DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_to     ON transactions (to_address, ts DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_chain  ON transactions (chain, ts DESC);

-- ── Blocks ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blocks (
    id              BIGSERIAL,
    ts              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    chain           TEXT        NOT NULL,
    block_number    BIGINT      NOT NULL,
    block_hash      TEXT        NOT NULL,
    parent_hash     TEXT,
    tx_count        INTEGER,
    gas_used        BIGINT,
    gas_limit       BIGINT,
    base_fee_wei    NUMERIC(40, 0),
    miner           TEXT,
    PRIMARY KEY (ts, id)
);

SELECT create_hypertable('blocks', 'ts', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_blocks_number ON blocks (chain, block_number DESC);

-- ── Anomalies ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS anomalies (
    id              BIGSERIAL,
    ts              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    chain           TEXT        NOT NULL,
    anomaly_type    TEXT        NOT NULL,   -- 'volume_spike' | 'gas_spike' | 'recirculation'
    severity        TEXT        NOT NULL,   -- 'low' | 'medium' | 'high' | 'critical'
    description     TEXT,
    tx_hash         TEXT,
    from_address    TEXT,
    value_eth       DOUBLE PRECISION,
    metadata        JSONB,
    alerted         BOOLEAN     DEFAULT FALSE,
    PRIMARY KEY (ts, id)
);

SELECT create_hypertable('anomalies', 'ts', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_anomalies_type ON anomalies (anomaly_type, ts DESC);
CREATE INDEX IF NOT EXISTS idx_anomalies_tx   ON anomalies (tx_hash) WHERE tx_hash IS NOT NULL;

-- ── Recirculation Paths ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS recirculation_paths (
    id              BIGSERIAL,
    ts              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    path_hash       TEXT        NOT NULL UNIQUE,    -- hash of the cycle for dedup
    hop_count       INTEGER     NOT NULL,
    total_value_wei NUMERIC(40, 0),
    addresses       TEXT[]      NOT NULL,
    tx_hashes       TEXT[]      NOT NULL,
    time_span_ms    BIGINT,
    PRIMARY KEY (ts, id)
);

SELECT create_hypertable('recirculation_paths', 'ts', if_not_exists => TRUE);

-- ── Continuous Aggregates ────────────────────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS tx_1min
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 minute', ts) AS bucket,
    chain,
    COUNT(*)                     AS tx_count,
    SUM(value_wei)               AS total_value_wei,
    AVG(gas_price_wei)           AS avg_gas_price,
    MAX(gas_price_wei)           AS max_gas_price
FROM transactions
GROUP BY bucket, chain
WITH NO DATA;

SELECT add_continuous_aggregate_policy('tx_1min',
    start_offset  => INTERVAL '1 hour',
    end_offset    => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute',
    if_not_exists => TRUE
);
