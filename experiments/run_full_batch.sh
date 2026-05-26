#!/usr/bin/env bash
# Master script for the unattended full batch.
# Runs: 9 more /refactor runs + 10 baseline runs + security audit.
# Logs progress to runs/_batch_progress.log so you can tail it any time.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

BATCH_LOG="${RUNS_DIR}/_batch_progress.log"
mkdir -p "${RUNS_DIR}"

# Set INTERACTIVE_CONFIRM=0 globally for this batch so child scripts don't prompt.
export INTERACTIVE_CONFIRM=0

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "${BATCH_LOG}"
}

log "=== full batch START ==="
log "harness: 9 refactor + 10 baseline + security audit"
log "budget cap: \$5/run × ~20 runs = \$100 hard ceiling"
log "expected wall: ~3 hours"

# ---- Phase A: 9 more /refactor runs ----------------------------------------
log "--- Phase A: /refactor (9 more runs) ---"
"${SCRIPT_DIR}/run_refactor.sh" 9 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: phase A had errors, continuing"

# ---- Phase B: 10 baseline runs ---------------------------------------------
log "--- Phase B: baseline (10 runs) ---"
"${SCRIPT_DIR}/run_baseline.sh" 10 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: phase B had errors, continuing"

# ---- Phase C: security audit -----------------------------------------------
log "--- Phase C: security audit ---"
"${SCRIPT_DIR}/run_security_audit.sh" 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: phase C had errors, continuing"

# ---- Phase D: aggregate ----------------------------------------------------
log "--- Phase D: aggregate ---"
python3 "${SCRIPT_DIR}/scoring/aggregate.py" 2>&1 | tee -a "${BATCH_LOG}" || log "WARN: aggregate failed"

log "=== full batch DONE ==="
