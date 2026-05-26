#!/usr/bin/env bash
# Run /refactor against a fresh copy of Slice 1, N times.
# Each run lives in its own runs/refactor-skill/run-NNN/ directory and
# captures: transcript, timing, full output snapshot of the AI's decomposition.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

PHASE_DIR="${RUNS_DIR}/refactor-skill"
mkdir -p "${PHASE_DIR}"

# Find the next run id (continues if prior runs already exist).
next_run_id() {
  local n=1
  while [[ -d "${PHASE_DIR}/run-$(printf '%03d' "${n}")" ]]; do
    n=$((n+1))
  done
  printf '%03d' "${n}"
}

# How many runs to do this invocation. Default to REFACTOR_RUNS but allow
# the user to override on the CLI: `./run_refactor.sh 3` for a smaller batch.
BATCH="${1:-${REFACTOR_RUNS}}"

echo "==> /refactor harness"
echo "    Slice 1 source:  ${SLICE1_REPO}"
echo "    Output base:     ${PHASE_DIR}"
echo "    Batch size:      ${BATCH} run(s)"
echo "    Model:           ${CLAUDE_MODEL}"
echo "    Timeout/run:     ${RUN_TIMEOUT_SECONDS}s"
echo

if [[ "${INTERACTIVE_CONFIRM}" == "1" ]]; then
  read -r -p "Start batch? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

for ((i=1; i<=BATCH; i++)); do
  RUN_ID="$(next_run_id)"
  RUN_DIR="${PHASE_DIR}/run-${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  WORK_DIR="${RUN_DIR}/output_repo"

  echo
  echo "==> Run ${RUN_ID} (${i}/${BATCH})"
  echo "    Working copy:  ${WORK_DIR}"

  # Fresh copy of the monolith every time so prior runs don't pollute state.
  rsync -a --delete \
    --exclude '.git' --exclude 'bin' --exclude 'obj' --exclude 'node_modules' \
    "${SLICE1_REPO}/" "${WORK_DIR}/"

  # Prompt is fixed across runs; it's the *only* user instruction supplied.
  # We tell Claude Code to use the /refactor skill and to proceed without
  # interactive confirmation (skill's "Proceed? yes/adjust" prompt).
  PROMPT="Use the /refactor skill to decompose this .NET monolith into microservices. When the skill presents its proposed decomposition, respond 'yes, proceed' and continue through every step until the decomposition is complete, including docker-compose and per-service Dockerfiles. Do not ask for further confirmation."

  START_TS="$(date +%s)"
  START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Non-interactive print mode; capture full transcript.
  (
    cd "${WORK_DIR}"
    gtimeout "${RUN_TIMEOUT_SECONDS}" claude \
      --print \
      --model "${CLAUDE_MODEL}" \
      --output-format stream-json \
      --verbose \
      --permission-mode acceptEdits \
      --max-budget-usd 5 \
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
  "started_at": "${START_ISO}",
  "ended_at": "${END_ISO}",
  "wall_clock_seconds": ${DURATION},
  "wall_clock_minutes": ${DURATION_MIN},
  "model": "${CLAUDE_MODEL}",
  "claude_cli": "${CLAUDE_CLI_VERSION:-unknown}",
  "timed_out": ${TIMED_OUT}
}
EOF

  echo "    Duration:      ${DURATION}s (${DURATION_MIN} min)"
  echo "    Artefacts:     ${RUN_DIR}"

  # Score immediately so we can spot bad runs early.
  if [[ -f "${SCRIPT_DIR}/scoring/score_decomposition.py" ]]; then
    python3 "${SCRIPT_DIR}/scoring/score_decomposition.py" \
      --repo "${WORK_DIR}" \
      --rubric "${SCRIPT_DIR}/dimensions.json" \
      --output "${RUN_DIR}/scoring.json" \
      || echo "    (scoring failed — inspect manually)"
    if [[ -f "${RUN_DIR}/scoring.json" ]]; then
      aligned="$(python3 -c "import json; d=json.load(open('${RUN_DIR}/scoring.json')); print(sum(1 for r in d['results'] if r['aligned']))")"
      echo "    Alignment:     ${aligned}/20"
    fi
  fi
done

echo
echo "==> Batch complete. Aggregate with: python3 scoring/aggregate.py"
