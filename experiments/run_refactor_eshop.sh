#!/usr/bin/env bash
# eShopOnWeb /refactor harness — transfer case study. N runs against a fresh
# rsync copy of the eShopOnWeb monolith each time. Outputs live under
# runs/eshop-refactor-skill/.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/config_eshop.env"

PHASE_DIR="${RUNS_DIR}/eshop-refactor-skill"
mkdir -p "${PHASE_DIR}"

next_run_id() {
  local n=1
  while [[ -d "${PHASE_DIR}/run-$(printf '%03d' "${n}")" ]]; do
    n=$((n+1))
  done
  printf '%03d' "${n}"
}

BATCH="${1:-${REFACTOR_RUNS}}"

echo "==> /refactor (eShopOnWeb)"
echo "    Source:    ${CODEBASE_REPO}"
echo "    Output:    ${PHASE_DIR}"
echo "    Batch:     ${BATCH} run(s)"
echo "    Model:     ${CLAUDE_MODEL}"
echo "    Timeout:   ${RUN_TIMEOUT_SECONDS}s"

if [[ "${INTERACTIVE_CONFIRM}" == "1" ]]; then
  read -r -p "Start batch? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

# Same minimal user prompt as PetRescue — invoke /refactor and proceed.
PROMPT="Use the /refactor skill to decompose this .NET monolith (eShopOnWeb) into microservices. When the skill presents its proposed decomposition, respond 'yes, proceed' and continue through every step until the decomposition is complete, including docker-compose and per-service Dockerfiles. Do not ask for further confirmation."

for ((i=1; i<=BATCH; i++)); do
  RUN_ID="$(next_run_id)"
  RUN_DIR="${PHASE_DIR}/run-${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  WORK_DIR="${RUN_DIR}/output_repo"

  echo
  echo "==> Run ${RUN_ID} (${i}/${BATCH})"

  rsync -a --delete \
    --exclude '.git' --exclude 'bin' --exclude 'obj' --exclude 'node_modules' \
    "${CODEBASE_REPO}/" "${WORK_DIR}/"

  START_TS="$(date +%s)"
  START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  (
    cd "${WORK_DIR}"
    gtimeout "${RUN_TIMEOUT_SECONDS}" claude \
      --print \
      --model "${CLAUDE_MODEL}" \
      --output-format stream-json \
      --verbose \
      --permission-mode acceptEdits \
      --max-budget-usd 8 \
      --no-session-persistence \
      "${PROMPT}" \
      > "${RUN_DIR}/transcript.jsonl" 2> "${RUN_DIR}/stderr.log" \
      || echo "RUN_EXIT=$?" > "${RUN_DIR}/exit_status.txt"
  )

  END_TS="$(date +%s)"
  END_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  DURATION=$((END_TS - START_TS))
  DURATION_MIN="$(python3 -c "print(f'{${DURATION}/60:.2f}')")"
  TIMED_OUT="false"
  [[ ${DURATION} -ge ${RUN_TIMEOUT_SECONDS} ]] && TIMED_OUT="true"

  cat > "${RUN_DIR}/timing.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "codebase": "${CODEBASE_TAG}",
  "started_at": "${START_ISO}",
  "ended_at": "${END_ISO}",
  "wall_clock_seconds": ${DURATION},
  "wall_clock_minutes": ${DURATION_MIN},
  "model": "${CLAUDE_MODEL}",
  "claude_cli": "${CLAUDE_CLI_VERSION:-unknown}",
  "timed_out": ${TIMED_OUT}
}
EOF

  echo "    Duration:  ${DURATION}s (${DURATION_MIN} min)"

  python3 "${CODEBASE_SCORER}" \
    --repo "${WORK_DIR}" \
    --rubric "${CODEBASE_RUBRIC}" \
    --output "${RUN_DIR}/scoring.json" \
    || echo "    (scoring failed)"

  if [[ -f "${RUN_DIR}/scoring.json" ]]; then
    aligned="$(python3 -c "import json; d=json.load(open('${RUN_DIR}/scoring.json')); print(sum(1 for r in d['results'] if r['aligned']))")"
    echo "    Alignment: ${aligned}/20"
  fi
done

echo
echo "==> eShop /refactor batch complete."
