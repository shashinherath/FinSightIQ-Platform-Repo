#!/usr/bin/env bash
# ==============================================================================
# FinSightIQ — Database Provisioning Script (On-Demand Runner)
# ==============================================================================
# Runs against the running PostgreSQL container to ensure all 5 logical
# databases exist. Safe and idempotent.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Checking PostgreSQL container status..."
if ! docker compose -f "${PLATFORM_DIR}/docker-compose.yml" ps --status running --services | grep -q "^postgres$"; then
  echo "[INFO] PostgreSQL container is not running. Starting postgres..."
  docker compose -f "${PLATFORM_DIR}/docker-compose.yml" up -d postgres
  echo "Waiting for PostgreSQL to become healthy..."
  until docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; do
    sleep 1
  done
fi

echo "Executing database provisioning inside postgres container..."
docker compose -f "${PLATFORM_DIR}/docker-compose.yml" exec -T postgres bash /docker-entrypoint-initdb.d/init-databases.sh

echo "[SUCCESS] All FinSightIQ logical databases provisioned."
