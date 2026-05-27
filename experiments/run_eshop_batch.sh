#!/usr/bin/env bash
# Master script for the eShopOnWeb transfer case study.
# Runs: 2 additional /refactor (after pilot=1, total N=3) + 3 baseline runs.
# Logs progress to runs/_eshop_batch_progress.log.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/config_eshop.env"

export INTERACTIVE_CONFIRM=0
BATCH_LOG="${RUNS_DIR}/_eshop_batch_progress.log"
mkdir -p "${RUNS_DIR}"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${BATCH_LOG}"
}

log "=== eShop transfer batch START ==="
log "harness: 2 more refactor (after pilot) + 3 baseline"

log "--- Phase A: eShop /refactor (2 more runs) ---"
"${SCRIPT_DIR}/run_refactor_eshop.sh" 2 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: phase A had errors"

log "--- Phase B: eShop baseline (3 runs) ---"
"${SCRIPT_DIR}/run_baseline_eshop.sh" 3 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: phase B had errors"

log "--- Phase C: aggregate ---"
python3 "${SCRIPT_DIR}/scoring/aggregate.py" "${RUNS_DIR}/eshop-refactor-skill" "${RUNS_DIR}/eshop-refactor-baseline" 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: aggregate failed"

log "=== eShop transfer batch DONE ==="
