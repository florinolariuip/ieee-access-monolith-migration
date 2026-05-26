#!/usr/bin/env bash
# Baseline: raw Claude with NO skill scripts. Same input monolith, same model,
# but the only instruction is a single natural-language prompt. This isolates
# what the LLM does by itself from what the skill engineering contributes.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

PHASE_DIR="${RUNS_DIR}/refactor-baseline"
mkdir -p "${PHASE_DIR}"

next_run_id() {
  local n=1
  while [[ -d "${PHASE_DIR}/run-$(printf '%03d' "${n}")" ]]; do
    n=$((n+1))
  done
  printf '%03d' "${n}"
}

BATCH="${1:-${BASELINE_RUNS}}"

echo "==> Baseline harness (raw Claude, no skills)"
echo "    Slice 1 source: ${SLICE1_REPO}"
echo "    Output base:    ${PHASE_DIR}"
echo "    Batch size:     ${BATCH} run(s)"
echo

if [[ "${INTERACTIVE_CONFIRM}" == "1" ]]; then
  read -r -p "Start batch? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

# Long, fully-specified prompt that any practitioner might write into a fresh
# Claude Code session without the skill library. We deliberately give it the
# same scope as /refactor produces, so the comparison is fair.
BASELINE_PROMPT=$(cat <<'EOF'
Read this .NET 10 ASP.NET Core monolith. Decompose it into independently
deployable microservices along its bounded contexts. Produce:

  - one ASP.NET Core project per bounded context
  - a YARP-based gateway that routes /api/* to the services
  - a separate DbContext per service (schema-isolated)
  - typed HttpClient classes for any inter-service calls
  - a docker-compose.yml that brings everything up against postgres
  - Dockerfiles per service targeting .NET 10 on ARM64
  - a README explaining how to run the system locally
  - an ARCHITECTURE.md describing the service boundaries

Do not ask for confirmation. Make all decisions yourself and produce a complete,
runnable result.
EOF
)

for ((i=1; i<=BATCH; i++)); do
  RUN_ID="$(next_run_id)"
  RUN_DIR="${PHASE_DIR}/run-${RUN_ID}"
  mkdir -p "${RUN_DIR}"
  WORK_DIR="${RUN_DIR}/output_repo"

  echo
  echo "==> Baseline run ${RUN_ID} (${i}/${BATCH})"

  rsync -a --delete \
    --exclude '.git' --exclude 'bin' --exclude 'obj' --exclude 'node_modules' \
    "${SLICE1_REPO}/" "${WORK_DIR}/"

  START_TS="$(date +%s)"
  START_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  (
    cd "${WORK_DIR}"
    # --disable-slash-commands removes /refactor, /architecture, etc. from the
    # session so the LLM must do the work from the natural-language prompt
    # alone. This is the clean isolation of "raw LLM" vs "skill-mediated".
    gtimeout "${RUN_TIMEOUT_SECONDS}" claude \
      --print \
      --model "${CLAUDE_MODEL}" \
      --output-format stream-json \
      --verbose \
      --permission-mode acceptEdits \
      --disable-slash-commands \
      --max-budget-usd 5 \
      --no-session-persistence \
      "${BASELINE_PROMPT}" \
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
  "kind": "baseline",
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
echo "==> Baseline batch complete."
