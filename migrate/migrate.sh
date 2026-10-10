#!/usr/bin/env bash
# ==============================================================================
# FinSightIQ — Flyway Database Migration Orchestration
# ==============================================================================
# Discovers and applies migrations from sibling service repositories in
# an isolated, ordered, and reproducible sequence.
# Each service migrations are strictly applied ONLY to its own logical database.
# Gracefully skips repositories that have not yet been created in early sprints.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(cd "${PLATFORM_DIR}/.." && pwd)"
ENV_FILE="${PLATFORM_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres_dev_password}"
FLYWAY_IMAGE="flyway/flyway:10-alpine"
DOCKER_NETWORK="finsightiq-network"

echo "=============================================================================="
echo "FinSightIQ Flyway Migration Orchestration"
echo "=============================================================================="
echo "Workspace Directory : ${WORKSPACE_DIR}"
echo "Docker Network      : ${DOCKER_NETWORK}"
echo "=============================================================================="

# 1. Ensure PostgreSQL is running and healthy
if ! docker compose -f "${PLATFORM_DIR}/docker-compose.yml" ps --status running --services | grep -q "^postgres$"; then
  echo "[INFO] PostgreSQL is not running. Starting postgres..."
  docker compose -f "${PLATFORM_DIR}/docker-compose.yml" up -d postgres
  echo "Waiting for PostgreSQL ready..."
  until docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; do
    sleep 1
  done
fi

# 2. Define service migration map (Ordered by dependency graph)
# Format: service_repo | target_database
SERVICE_MAP=(
  "finsightiq-user-service|usersdb"
  "finsightiq-market-data-service|marketdb"
  "finsightiq-prediction-service|predictiondb"
  "finsightiq-sentiment-service|sentimentdb"
  "finsightiq-portfolio-service|portfoliodb"
)

applied_count=0
skipped_count=0
failed_count=0

for entry in "${SERVICE_MAP[@]}"; do
  repo="${entry%%|*}"
  db="${entry##*|}"
  migrations_dir="${WORKSPACE_DIR}/${repo}/db/migrations"

  echo ""
  echo "--> Service: ${repo} (Target Database: ${db})"

  if [[ ! -d "${migrations_dir}" ]]; then
    echo "    [SKIPPED] Migration directory not found: ${migrations_dir}"
    echo "              Repository '${repo}' may not yet be initialized in current sprint."
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Check if there are any .sql files
  sql_count=$(find "${migrations_dir}" -maxdepth 1 -name "*.sql" 2>/dev/null | wc -l)
  if [[ "${sql_count}" -eq 0 ]]; then
    echo "    [SKIPPED] No .sql migration files found in ${migrations_dir}."
    skipped_count=$((skipped_count + 1))
    continue
  fi

  echo "    Found ${sql_count} migration file(s). Executing Flyway migrate..."
  
  # Execute Flyway via Docker container attached to the platform network
  set +e
  docker run --rm \
    --network "${DOCKER_NETWORK}" \
    -v "${migrations_dir}:/flyway/sql:ro" \
    "${FLYWAY_IMAGE}" \
    -url="jdbc:postgresql://postgres:5432/${db}" \
    -user="${POSTGRES_USER}" \
    -password="${POSTGRES_PASSWORD}" \
    -connectRetries=10 \
    migrate
  flyway_exit=$?
  set -e

  if [[ ${flyway_exit} -eq 0 ]]; then
    echo "    [OK] Successfully migrated database '${db}'."
    applied_count=$((applied_count + 1))
  else
    echo "    [ERROR] Flyway migration failed for service '${repo}' on database '${db}' (Exit code: ${flyway_exit})." >&2
    failed_count=$((failed_count + 1))
    break
  fi
done

echo ""
echo "=============================================================================="
echo "Migration Summary:"
echo "  Applied: ${applied_count}"
echo "  Skipped: ${skipped_count}"
echo "  Failed : ${failed_count}"
echo "=============================================================================="

if [[ ${failed_count} -gt 0 ]]; then
  echo "[FAILURE] Database migration orchestration encountered an error." >&2
  exit 1
fi

echo "[SUCCESS] Migration orchestration finished cleanly."
exit 0
