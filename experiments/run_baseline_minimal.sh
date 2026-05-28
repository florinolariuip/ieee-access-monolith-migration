#!/usr/bin/env bash
# Matched-specificity (minimal-prompt) baseline harness for PetRescue.
# Third experimental condition isolating the role of prompt specificity:
# same model, same input, NO skill scripts, AND a deliberately vague
# user prompt. This is what a practitioner who has not invested in
# prompt engineering would actually type.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

PHASE_DIR="${RUNS_DIR}/refactor-baseline-minimal"
mkdir -p "${PHASE_DIR}"

next_run_id() {
  local n=1
  while [[ -d "${PHASE_DIR}/run-$(printf '%03d' "${n}")" ]]; do
    n=$((n+1))
  done
  printf '%03d' "${n}"
}

BATCH="${1:-5}"

echo "==> Minimal-prompt baseline harness (raw Claude, no skills, vague prompt)"
echo "    Source:    ${SLICE1_REPO}"
echo "    Output:    ${PHASE_DIR}"
echo "    Batch:     ${BATCH} run(s)"
echo

if [[ "${INTERACTIVE_CONFIRM}" == "1" ]]; then
  read -r -p "Start batch? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

# Single-sentence prompt. No enumeration of deliverables. This represents
# the "naive practitioner" condition for the prompt-specificity ablation.
MINIMAL_PROMPT="Decompose this .NET monolith into microservices and make it deployable."

for ((i=1; i<=BATCH; i++)); do
  RUN_ID="$(next_run_id)"
  RUN_DIR="${PHASE_DIR}/run-${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  WORK_DIR="${RUN_DIR}/output_repo"

  echo
  echo "==> Minimal run ${RUN_ID} (${i}/${BATCH})"

  rsync -a --delete \
    --exclude '.git' --exclude 'bin' --exclude 'obj' --exclude 'node_modules' \
    "${SLICE1_REPO}/" "${WORK_DIR}/"

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
      --disable-slash-commands \
      --max-budget-usd 5 \
      --no-session-persistence \
      "${MINIMAL_PROMPT}" \
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
  "kind": "baseline-minimal",
  "prompt": "minimal-single-sentence",
  "started_at": "${START_ISO}",
  "ended_at": "${END_ISO}",
  "wall_clock_seconds": ${DURATION},
  "wall_clock_minutes": ${DURATION_MIN},
  "model": "${CLAUDE_MODEL}",
  "timed_out": ${TIMED_OUT}
}
EOF

  python3 "${SCRIPT_DIR}/scoring/score_decomposition.py" \
    --repo "${WORK_DIR}" \
    --rubric "${SCRIPT_DIR}/dimensions.json" \
    --output "${RUN_DIR}/scoring.json" \
    || echo "    (scoring failed)"

  if [[ -f "${RUN_DIR}/scoring.json" ]]; then
    aligned="$(python3 -c "import json; d=json.load(open('${RUN_DIR}/scoring.json')); print(sum(1 for r in d['results'] if r['aligned']))")"
    echo "    Duration: ${DURATION}s — Alignment: ${aligned}/20"
  fi
done

echo
echo "==> Minimal baseline batch complete."
