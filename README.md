# FinSightIQ Platform Orchestration

[![Platform CI](https://github.com/shashinherath/FinSightIQ-Platform-Repo/actions/workflows/ci.yml/badge.svg)](https://github.com/shashinherath/FinSightIQ-Platform-Repo/actions/workflows/ci.yml)
[![Docker Compose v2](https://img.shields.io/badge/Docker%20Compose-v2-blue.svg)](https://docs.docker.com/compose/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D.svg)](https://redis.io/)
[![RabbitMQ](https://img.shields.io/badge/RabbitMQ-3.12-FF6600.svg)](https://www.rabbitmq.com/)

> **FinSightIQ** is an AI-powered stock prediction and portfolio analytics platform built on a polyrepo microservices architecture.  
> The `finsightiq-platform` repository serves as the **front door** for the entire system: coordinating local orchestration, multi-database provisioning, Flyway migrations, demo data seeding, observability, cross-service testing, and workspace locking.

---

## Table of Contents

1. [Purpose and Scope](#1-purpose-and-scope)
2. [Architecture and Repository Boundaries](#2-architecture-and-repository-boundaries)
3. [Workspace Structure](#3-workspace-structure)
4. [Prerequisites and Verified Versions](#4-prerequisites-and-verified-versions)
5. [Initial Setup](#5-initial-setup)
6. [Environment Configuration](#6-environment-configuration)
7. [Bootstrap Usage & Version Locking](#7-bootstrap-usage--version-locking)
8. [Docker Compose Startup](#8-docker-compose-startup)
9. [Database Provisioning](#9-database-provisioning)
10. [Flyway Migration Execution](#10-flyway-migration-execution)
11. [Demo Data Seeding](#11-demo-data-seeding)
12. [Monitoring & Observability](#12-monitoring--observability)
13. [Testing Commands](#13-testing-commands)
14. [Troubleshooting](#14-troubleshooting)
15. [Windows-Specific Setup Notes](#15-windows-specific-setup-notes)
16. [Safe Shutdown and Reset Procedures](#16-safe-shutdown-and-reset-procedures)

---

## 1. Purpose and Scope

The `finsightiq-platform` repository owns platform engineering concerns across the FinSightIQ polyrepo ecosystem:
- **Local Development Orchestration**: Docker Compose v2 configurations for infrastructure (`PostgreSQL 15`, `Redis 7`, `RabbitMQ 3.12`) and application microservices.
- **Multi-Database Management**: Automated idempotent provisioning of five isolated logical databases (`usersdb`, `marketdb`, `predictiondb`, `portfoliodb`, `sentimentdb`).
- **Migration Orchestration**: Discovery and execution of Flyway migrations sourced directly from individual service repositories.
- **Seeding & Fixtures**: Idempotent demo data population for local development.
- **Observability**: Prometheus metrics scraping configuration and Grafana dashboards.
- **CI/CD Platform Workflows**: Reusable GitHub Actions workflows (`dotnet-ci.yml`) and platform validation suites (`ci.yml`).
- **Workspace Bootstrapping**: Deterministic synchronization of sibling repositories pinned via `workspace.lock`.

> **Architectural Boundary Rule:** The platform repository **does not** contain application business logic, domain entities, controllers, or service-specific database migrations. Each business capability is owned exclusively by its respective microservice repository.

---

## 2. Architecture and Repository Boundaries

FinSightIQ decomposes functionality across 13 repositories:

```text
                        Browser (React 18 SPA — finsightiq-web)
                                       |
                              HTTPS / WebSocket
                                       |
                      +----------------------------------+
                      |    API Gateway (YARP)            |  finsightiq-gateway
                      |    JWT · Routing · Rate Limiting |
                      +----------------------------------+
                                       |
        +-------------+------------+---+----------+-------------+
        |             |            |              |             |
   User Service  Market Data  Prediction     Portfolio     Sentiment
   (.NET 8)      (.NET 8)     Service        Service       Service
        |             |       (.NET 8)       (.NET 8)      (.NET 8)
        |             |            |              |             |
        |             |       Python AI           |         FinBERT NLP
        |             |       Engine (3.12)       |         Engine (3.12)
        |             |            |              |             |
     usersdb       marketdb   predictiondb   portfoliodb   sentimentdb
        \             \            |              /             /
         +-------------+-----------+-------------+-------------+
                                   |
                      Redis 7  ·  RabbitMQ 3.12
```

### Shared Libraries & Contracts
- `finsightiq-building-blocks`: Shared .NET types (`Result<T>`, `PagedResult<T>`, Serilog correlation middleware). Published to GitHub Packages.
- `finsightiq-contracts`: Strongly-typed event contracts (`PriceUpdated`, `PredictionGenerated`, `SentimentShifted`) and JSON Schemas.

---

## 3. Workspace Structure

All 13 repositories sit side-by-side as siblings inside a single workspace folder (`finsightiq-workspace/`):

```text
finsightiq-workspace/
├── finsightiq-platform/             # Platform orchestration (This repository)
├── finsightiq-docs/                 # Architecture, specifications, and ADRs
├── finsightiq-building-blocks/      # Shared .NET package (NuGet)
├── finsightiq-contracts/            # Shared event contracts & JSON Schemas
├── finsightiq-gateway/              # YARP API Gateway (.NET 8)
├── finsightiq-user-service/         # User & Auth Service (.NET 8)
├── finsightiq-market-data-service/  # Market Data Ingestion & Storage (.NET 8)
├── finsightiq-prediction-service/   # Prediction Orchestration (.NET 8)
├── finsightiq-portfolio-service/    # Portfolio & Valuation Service (.NET 8)
├── finsightiq-sentiment-service/    # Sentiment Ingestion & Scoring (.NET 8)
├── finsightiq-ai-engine/            # Forecasting Models (Python 3.12, FastAPI)
├── finsightiq-nlp-engine/           # FinBERT NLP Scoring (Python 3.12, FastAPI)
└── finsightiq-web/                  # Frontend SPA (React 18, Vite, TypeScript)
```

---

## 4. Prerequisites and Verified Versions

Ensure the following tools are installed and verified:

| Tool | Minimum Version | Verification Command | Notes |
|---|---|---|---|
| **Docker Engine** | 24.0+ (Tested: 28.4) | `docker --version` | Docker Desktop or Linux Engine |
| **Docker Compose** | v2.20+ (Tested: v2.39) | `docker compose version` | Built into modern Docker CLI |
| **Git** | 2.40+ (Tested: 2.56) | `git --version` | Required for multi-repo checkout |
| **.NET SDK** | 8.0+ (Tested: 10.0) | `dotnet --version` | Required for compiling C# services |
| **Python** | 3.10+ / 3.12 | `python --version` | Required for AI and NLP services |
| **Node.js** | 20.x+ | `node --version` | Required for E2E tests and web client |
| **GNU Make / Bash** | Optional on Windows | `make --version` / `bash --version` | Native PowerShell alternatives provided |

---

## 5. Initial Setup

1. Open a terminal in your workspace directory (parent of `finsightiq-platform`).
2. Navigate into `finsightiq-platform`:
   ```bash
   cd finsightiq-platform
   ```
3. Initialize your local `.env` configuration file from the template:
   ```bash
   cp .env.example .env
   ```
   *(On Windows PowerShell: `Copy-Item .env.example .env`)*

4. Edit `.env` and set your GitHub username / organization:
   ```ini
   FINSIGHTIQ_OWNER=shashinherath
   NUGET_TOKEN=ghp_your_read_packages_token_here
   ```

---

## 6. Environment Configuration

Configuration follows Twelve-Factor principles. The platform template (`.env.example`) defines safe defaults for local development:

- `FINSIGHTIQ_OWNER`: GitHub username or organization owning the repositories.
- `NUGET_TOKEN`: Personal Access Token with `read:packages` permission (required for building .NET containers using private NuGet packages).
- `POSTGRES_USER` / `POSTGRES_PASSWORD`: Administrative credentials for the local container.
- `REDIS_PASSWORD`: Redis authentication password.
- `RABBITMQ_DEFAULT_USER` / `RABBITMQ_DEFAULT_PASS`: RabbitMQ credentials.
- `ALPHA_VANTAGE_API_KEY`: API key for primary market data ingestion.
- `NEWS_API_KEY`: API key for news sentiment ingestion.

> **Security Rule:** Never commit `.env` or real API keys to version control. The `.gitignore` file enforces that `.env` is ignored.

---

## 7. Bootstrap Usage & Version Locking

The platform uses `workspace.lock` to deterministically pin the Git ref (tag, branch, or SHA) for every sibling repository.

### Running Bootstrap
To clone missing sibling repositories and align existing ones to the locked refs:

- **Using Bash / Make:**
  ```bash
  make bootstrap
  # or directly:
  ./bootstrap.sh
  ```
- **Using PowerShell (Windows):**
  ```powershell
  .\bootstrap.ps1
  # or via helper:
  .\scripts\dev.ps1 bootstrap
  ```

### Developer Branching Workflow
`bootstrap.sh` checks out pinned refs in a detached `HEAD` state. When you want to develop a feature in a sibling repository:
```bash
cd ../finsightiq-user-service
git checkout -b feat/my-new-feature
```
`bootstrap.sh` detects uncommitted local changes and will **never** overwrite or reset your work without explicit permission.

---

## 8. Docker Compose Startup

### 1. Core Infrastructure Only (PostgreSQL, Redis, RabbitMQ)
```bash
make up
# or PowerShell:
.\scripts\dev.ps1 up
# or Docker Compose directly:
docker compose up -d postgres redis rabbitmq
```

### 2. Core Infrastructure + Observability (Prometheus & Grafana)
```bash
make up-monitoring
# or PowerShell:
.\scripts\dev.ps1 up-monitoring
# or Docker Compose directly:
docker compose --profile monitoring up -d
```

### 3. Full Platform Stack (All Microservices + Infrastructure)
Once sibling services are cloned and populated:
```bash
make up-all
# or PowerShell:
.\scripts\dev.ps1 up-all
# or Docker Compose directly:
docker compose --profile monitoring --profile services up -d --build
```

---

## 9. Database Provisioning

FinSightIQ utilizes a single PostgreSQL 15 container hosting five isolated logical databases:
1. `usersdb`
2. `marketdb`
3. `predictiondb`
4. `portfoliodb`
5. `sentimentdb`

### Automatic Provisioning
When the PostgreSQL container starts for the first time, `migrate/init-databases.sh` is automatically executed via `/docker-entrypoint-initdb.d/`.

### Manual / On-Demand Provisioning
To verify or provision any missing databases at any time:
```bash
make provision
# or PowerShell:
.\scripts\dev.ps1 provision
```
*This command is completely idempotent. Existing databases and data are never dropped or modified.*

---

## 10. Flyway Migration Execution

Each microservice owns its schema and forward-only SQL migrations in `<service-repo>/db/migrations/`.

The platform migration orchestrator runs Flyway in an isolated container per service database:
```bash
make migrate
# or PowerShell:
.\scripts\dev.ps1 migrate
```

### How Migration Discovery Works:
1. Sequentially checks the migration directories of all services in dependency order (`user-service` -> `market-data-service` -> `prediction-service` -> `sentiment-service` -> `portfolio-service`).
2. If a repository has not been created yet in the current sprint, it is clearly reported as `[SKIPPED]`.
3. If migrations are present, Flyway applies them to that service's target database only.
4. Any failure terminates execution immediately with a non-zero exit code.

---

## 11. Demo Data Seeding

Once migrations have created the tables, seed development fixtures:
```bash
make seed
# or PowerShell:
.\scripts\dev.ps1 seed
```

### Included Synthetic Fixtures:
- **`usersdb`**:
  - `admin@finsightiq.local` (Administrator, password: `Admin123!`)
  - `analyst@finsightiq.local` (Analyst, password: `Analyst123!`)
  - `viewer@finsightiq.local` (Viewer, password: `Viewer123!`)
- **`marketdb`**:
  - 30 standard stock symbols across all market sectors (e.g. `AAPL`, `MSFT`, `GOOGL`, `AMZN`, `NVDA`, `TSLA`, `JPM`).

*The seeding script checks table existence before inserting and skips any service whose migrations have not yet been run.*

---

## 12. Monitoring & Observability

When running with `--profile monitoring`, the following dashboards are available:

| Service | Local URL | Credentials (Local Dev) | Description |
|---|---|---|---|
| **Prometheus** | [http://localhost:9090](http://localhost:9090) | None | Metrics scraper and PromQL interface |
| **Grafana** | [http://localhost:3000](http://localhost:3000) | `admin` / `admin_dev_password` | Pre-configured platform dashboards |
| **RabbitMQ Management** | [http://localhost:15672](http://localhost:15672) | `guest` / `guest` | Event broker queues & exchanges |
| **API Gateway** | [http://localhost:5000](http://localhost:5000) | — | YARP reverse proxy and health checks |
| **Gateway Swagger** | [http://localhost:5000/swagger](http://localhost:5000/swagger) | — | Unified API documentation |

---

## 13. Testing Commands

### View Container Health
```bash
make ps
# or PowerShell:
.\scripts\dev.ps1 ps
```

### Run Platform E2E Tests (Playwright)
```bash
cd tests/e2e
npm install
npm test
```

### Run Load Tests (k6)
```bash
k6 run tests/load/baseline.js
```

---

## 14. Troubleshooting

### Port Conflicts (e.g., 5432, 6379 already in use)
If local instances of PostgreSQL or Redis are running on your host machine, modify the host port mappings in `.env`:
```ini
PORT_POSTGRES=5433
PORT_REDIS=6380
```

### Docker Volume Permission Issues
If containers fail to write to volumes, run `make down` and verify Docker Desktop file sharing permissions.

### Docker Build Fails with NuGet 401 Unauthorized
Building .NET containers requires access to the private `finsightiq-building-blocks` package on GitHub Packages.
Ensure `NUGET_TOKEN` is defined in `.env` with a Personal Access Token that has `read:packages` permission.

---

## 15. Windows-Specific Setup Notes

- **Docker Desktop**: Ensure Docker Desktop is configured to use the **WSL 2 backend**.
- **PowerShell Execution Policy**: If PowerShell scripts are blocked, enable execution for the current process:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  ```
- **Line Endings (`core.autocrlf`)**: Shell scripts (`.sh`) must retain LF line endings to execute properly inside Linux containers. Ensure Git does not convert them to CRLF:
  ```bash
  git config core.autocrlf input
  ```

---

## 16. Safe Shutdown and Reset Procedures

### Non-Destructive Stop (Preserves Database Data)
```bash
make down
# or PowerShell:
.\scripts\dev.ps1 down
```

### Destructive Reset (Wipes All Containers and Data Volumes)
> **Caution:** This permanently erases all databases, cached keys, and queue messages!
```bash
make reset
# or PowerShell:
.\scripts\dev.ps1 reset
```
Requires explicit typed confirmation (`yes`) before proceeding.
