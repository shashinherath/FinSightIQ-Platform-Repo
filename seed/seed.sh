#!/usr/bin/env bash
# ==============================================================================
# FinSightIQ — Demo & Test Data Seeding Orchestrator
# ==============================================================================
# Safely inspects provisioned database tables before seeding demo fixtures.
# Idempotent: Never inserts duplicates or mutates existing business data.
# Skips services whose schemas have not yet been migrated.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${PLATFORM_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"

echo "=============================================================================="
echo "FinSightIQ Demo Data Seeding Orchestration"
echo "=============================================================================="

# Ensure postgres is running
if ! docker compose -f "${PLATFORM_DIR}/docker-compose.yml" ps --status running --services | grep -q "^postgres$"; then
  echo "[INFO] PostgreSQL is not running. Starting postgres..."
  docker compose -f "${PLATFORM_DIR}/docker-compose.yml" up -d postgres
  echo "Waiting for PostgreSQL ready..."
  until docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; do
    sleep 1
  done
fi

seeded_count=0
skipped_count=0

# ------------------------------------------------------------------------------
# 1. usersdb — Demo Accounts
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking 'usersdb' (User Service)..."
table_exists=$(docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d usersdb -tAc \
  "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users');" 2>/dev/null || echo "false")

if [[ "${table_exists}" == "t" ]]; then
  echo "    Applying demo user accounts..."
  docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
    psql -U "${POSTGRES_USER}" -d usersdb < "${SCRIPT_DIR}/sql/users_seed.sql"
  echo "    [SEEDED] Successfully seeded default demo users (admin, analyst, viewer)."
  seeded_count=$((seeded_count + 1))
else
  echo "    [SKIPPED] Table 'users' does not exist in 'usersdb'."
  echo "              User Service migrations have not been executed yet."
  skipped_count=$((skipped_count + 1))
fi

# ------------------------------------------------------------------------------
# 2. marketdb — Market Symbols
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking 'marketdb' (Market Data Service)..."
symbols_table_exists=$(docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d marketdb -tAc \
  "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'symbols');" 2>/dev/null || echo "false")

if [[ "${symbols_table_exists}" == "t" ]]; then
  echo "    Applying 30 standard market symbols..."
  docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
    psql -U "${POSTGRES_USER}" -d marketdb < "${SCRIPT_DIR}/sql/market_symbols_seed.sql"
  echo "    [SEEDED] Successfully seeded 30 stock market symbols."
  seeded_count=$((seeded_count + 1))
else
  echo "    [SKIPPED] Table 'symbols' does not exist in 'marketdb'."
  echo "              Market Data Service migrations have not been executed yet."
  skipped_count=$((skipped_count + 1))
fi

# ------------------------------------------------------------------------------
# 3. predictiondb, portfoliodb, sentimentdb
# ------------------------------------------------------------------------------
echo ""
echo "--> Checking 'predictiondb'..."
pred_exists=$(docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d predictiondb -tAc \
  "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'predictions');" 2>/dev/null || echo "false")
if [[ "${pred_exists}" == "t" ]]; then
  echo "    [INFO] Prediction table exists."
else
  echo "    [SKIPPED] Prediction Service tables not yet migrated."
  skipped_count=$((skipped_count + 1))
fi

echo ""
echo "--> Checking 'portfoliodb'..."
port_exists=$(docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d portfoliodb -tAc \
  "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'portfolios');" 2>/dev/null || echo "false")
if [[ "${port_exists}" == "t" ]]; then
  echo "    [INFO] Portfolio tables exist."
else
  echo "    [SKIPPED] Portfolio Service tables not yet migrated."
  skipped_count=$((skipped_count + 1))
fi

echo ""
echo "--> Checking 'sentimentdb'..."
sent_exists=$(docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres \
  psql -U "${POSTGRES_USER}" -d sentimentdb -tAc \
  "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sentiment_scores');" 2>/dev/null || echo "false")
if [[ "${sent_exists}" == "t" ]]; then
  echo "    [INFO] Sentiment tables exist."
else
  echo "    [SKIPPED] Sentiment Service tables not yet migrated."
  skipped_count=$((skipped_count + 1))
fi

echo ""
echo "=============================================================================="
echo "Seeding Summary:"
echo "  Datasets Seeded : ${seeded_count}"
echo "  Datasets Skipped: ${skipped_count}"
echo "=============================================================================="
echo "[SUCCESS] Demo seeding orchestration completed."
exit 0
