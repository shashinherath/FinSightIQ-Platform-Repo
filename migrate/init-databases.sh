#!/usr/bin/env bash
# ==============================================================================
# FinSightIQ — PostgreSQL Multi-Database Initialization Script
# ==============================================================================
# Mounted to /docker-entrypoint-initdb.d/init-databases.sh in the PostgreSQL container.
# Idempotent: checks for existence before creating.
# Never drops, recreates, or modifies existing databases or data.
# ==============================================================================
set -euo pipefail

DATABASES=(
  "usersdb"
  "marketdb"
  "predictiondb"
  "portfoliodb"
  "sentimentdb"
)

DEFAULT_DB="${POSTGRES_DB:-postgres}"
ADMIN_USER="${POSTGRES_USER:-postgres}"

echo "=============================================================================="
echo "FinSightIQ: Provisioning Logical Microservice Databases"
echo "Administrative User: ${ADMIN_USER}"
echo "Connecting to      : ${DEFAULT_DB}"
echo "=============================================================================="

for db in "${DATABASES[@]}"; do
  # Check if database already exists
  EXISTS=$(psql -v ON_ERROR_STOP=1 --username "${ADMIN_USER}" --dbname "${DEFAULT_DB}" -tAc "SELECT 1 FROM pg_database WHERE datname = '${db}'")
  if [[ "${EXISTS}" == "1" ]]; then
    echo "  [EXISTS] Database '${db}' already present. Preserving existing data."
  else
    echo "  [CREATE] Creating database '${db}'..."
    psql -v ON_ERROR_STOP=1 --username "${ADMIN_USER}" --dbname "${DEFAULT_DB}" -c "CREATE DATABASE \"${db}\";"
    echo "  [OK]     Database '${db}' created successfully."
  fi
done

echo "=============================================================================="
echo "Database provisioning completed successfully."
echo "=============================================================================="
