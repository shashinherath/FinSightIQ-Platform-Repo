#!/usr/bin/env bash
# ==============================================================================
# FinSightIQ — Workspace Bootstrap Script
# ==============================================================================
# Clones and aligns sibling repositories defined in workspace.lock.
# Leaves repositories at locked refs for reproducibility.
# Safe: Never overwrites uncommitted local changes.
# ==============================================================================
set -euo pipefail
export GIT_TERMINAL_PROMPT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOCK_FILE="${SCRIPT_DIR}/workspace.lock"
ENV_FILE="${SCRIPT_DIR}/.env"

echo "=============================================================================="
echo "FinSightIQ Workspace Bootstrapper"
echo "=============================================================================="
echo "Platform Directory : ${SCRIPT_DIR}"
echo "Workspace Directory: ${WORKSPACE_DIR}"

# 1. Load configuration safely
if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${SCRIPT_DIR}/.env.example" ]]; then
    echo "[WARN] .env not found. Creating from .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "${ENV_FILE}"
  else
    echo "[ERROR] .env and .env.example missing in ${SCRIPT_DIR}." >&2
    exit 1
  fi
fi

# Export variables from .env
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

# 2. Validate FINSIGHTIQ_OWNER
if [[ -z "${FINSIGHTIQ_OWNER:-}" || "${FINSIGHTIQ_OWNER}" == "YOUR_GITHUB_ORG_OR_USER" ]]; then
  echo "[ERROR] FINSIGHTIQ_OWNER is not configured in ${ENV_FILE}." >&2
  echo "Please set FINSIGHTIQ_OWNER to your GitHub username or organization." >&2
  exit 1
fi
echo "GitHub Owner       : ${FINSIGHTIQ_OWNER}"
echo "=============================================================================="

# 3. Validate workspace.lock
if [[ ! -f "${LOCK_FILE}" ]]; then
  echo "[ERROR] workspace.lock not found at ${LOCK_FILE}" >&2
  exit 1
fi

cloned_count=0
existing_count=0
skipped_count=0
failed_count=0

# 4. Iterate over locked repositories
while read -r repo ref || [[ -n "${repo:-}" ]]; do
  # Skip comments and blank lines
  [[ -z "${repo:-}" || "${repo}" =~ ^[[:space:]]*# ]] && continue
  # Extract first two tokens
  repo=$(echo "${repo}" | awk '{print $1}')
  ref=$(echo "${ref:-}" | awk '{print $1}')
  
  if [[ -z "${ref}" ]]; then
    ref="main"
  fi

  target_dir="${WORKSPACE_DIR}/${repo}"
  # Check common naming variations if default target does not exist
  if [[ ! -d "${target_dir}" ]]; then
    if [[ "${repo}" == "finsightiq-web" && -d "${WORKSPACE_DIR}/FinSightIQ-Frontend-Repo" ]]; then
      target_dir="${WORKSPACE_DIR}/FinSightIQ-Frontend-Repo"
    elif [[ "${repo}" == "finsightiq-docs" && -d "${WORKSPACE_DIR}/Docs" ]]; then
      target_dir="${WORKSPACE_DIR}/Docs"
    fi
  fi

  echo ""
  echo "--> Processing repository: ${repo} (Target ref: ${ref})"

  if [[ ! -d "${target_dir}" ]]; then
    repo_url="https://github.com/${FINSIGHTIQ_OWNER}/${repo}.git"
    echo "    Cloning from ${repo_url} into ${target_dir}..."
    if git clone "${repo_url}" "${target_dir}" 2>/dev/null; then
      echo "    [OK] Cloned successfully."
      cloned_count=$((cloned_count + 1))
    else
      echo "    [WARN] Repository '${repo}' could not be cloned (may not exist yet on GitHub)."
      echo "           Skipping '${repo}' without failure."
      skipped_count=$((skipped_count + 1))
      continue
    fi
  else
    echo "    Directory exists: ${target_dir}"
    existing_count=$((existing_count + 1))
  fi

  # Check if it is a valid git repository
  if ! git -C "${target_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "    [NOTE] '${target_dir}' is not a git repository. Skipping ref checkout."
    continue
  fi

  # Check for uncommitted changes
  if [[ -n "$(git -C "${target_dir}" status --porcelain)" ]]; then
    echo "    [PRESERVED] Repository has uncommitted changes. Skipping checkout to prevent data loss."
    continue
  fi

  # Fetch and checkout target ref
  echo "    Fetching remote tags and branches..."
  git -C "${target_dir}" fetch --tags --quiet origin || true

  if git -C "${target_dir}" checkout --quiet "${ref}" 2>/dev/null; then
    echo "    [OK] Checked out '${ref}' (HEAD is at $(git -C "${target_dir}" rev-parse --short HEAD))."
    echo "         NOTE: To start active feature work, run: git checkout -b feat/<name>"
  else
    echo "    [ERROR] Failed to check out ref '${ref}' in ${repo}." >&2
    failed_count=$((failed_count + 1))
  fi

done < "${LOCK_FILE}"

echo ""
echo "=============================================================================="
echo "Bootstrap Summary:"
echo "  Cloned  : ${cloned_count}"
echo "  Existing: ${existing_count}"
echo "  Skipped : ${skipped_count} (uncreated remote repos)"
echo "  Failed  : ${failed_count}"
echo "=============================================================================="

if [[ ${failed_count} -gt 0 ]]; then
  echo "[FAILURE] One or more repositories failed ref checkout." >&2
  exit 1
fi

echo "[SUCCESS] Workspace synchronization complete."
exit 0
