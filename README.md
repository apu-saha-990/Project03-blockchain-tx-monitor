# Project 3 — Real-Time Blockchain Transaction Monitor

> Production-grade real-time blockchain transaction monitoring with mempool streaming, anomaly detection, forensic recirculation analysis, time-series storage, and a headless terminal dashboard.

---

## Architecture

```
Alchemy WS ──► Stream Manager ──► Filter Chain ──► Anomaly Engine ──► Alerts
                                        │                │
                                        ▼                ▼
                                  TimescaleDB      Prometheus
                                        │
                                        ▼
                                  Terminal UI / Grafana
```

## Stack

| Layer | Technology |
|---|---|
| Data Ingestion | Python + WebSocket (Alchemy) |
| Terminal UI | Python Rich |
| Database | PostgreSQL + TimescaleDB |
| Monitoring | Prometheus + Grafana |
| Alerting | Alertmanager + Discord/Slack |
| Orchestration | Docker Compose + Kubernetes |
| CI/CD | GitHub Actions |

## Quick Start

```bash
cp .env.example .env
# fill in ALCHEMY_API_KEY, DATABASE_URL, webhook URLs

docker compose up -d
python -m src.main
```

## Project Structure

```
src/
├── ingestion/      # WebSocket clients, stream manager
├── filters/        # Value, gas, contract, token filters
├── analysis/       # Anomaly detection, recirculation
├── storage/        # TimescaleDB client, schema, migrations
├── alerting/       # Alert engine, Discord, Slack
├── metrics/        # Prometheus exporters
└── dashboard/      # Rich terminal UI
```

---

*Part of the Blockchain Infrastructure Portfolio — see portfolio overview for context.*
