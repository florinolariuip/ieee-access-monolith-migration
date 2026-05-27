#!/usr/bin/env bash
# eShopOnWeb baseline harness — raw Claude with no skills. Same input
# monolith, fully-specified prompt enumerating the intended deliverables
# (mirroring how the PetRescue baseline was constructed, but with the
# eShop bounded contexts and .NET 8 target).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"
source "${SCRIPT_DIR}/config_eshop.env"

PHASE_DIR="${RUNS_DIR}/eshop-refactor-baseline"
mkdir -p "${PHASE_DIR}"

next_run_id() {
  local n=1
  while [[ -d "${PHASE_DIR}/run-$(printf '%03d' "${n}")" ]]; do
    n=$((n+1))
  done
  printf '%03d' "${n}"
}

BATCH="${1:-${BASELINE_RUNS}}"

echo "==> Baseline (eShopOnWeb, no skills)"
echo "    Source:    ${CODEBASE_REPO}"
echo "    Output:    ${PHASE_DIR}"
echo "    Batch:     ${BATCH} run(s)"

if [[ "${INTERACTIVE_CONFIRM}" == "1" ]]; then
  read -r -p "Start batch? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 1; }
fi

BASELINE_PROMPT=$(cat <<'EOF'
Read this .NET 8 ASP.NET Core monolith (eShopOnWeb) and decompose it into
independently deployable microservices along its bounded contexts.
The reference decomposition by Microsoft (eShopOnContainers) splits it into
Catalog, Basket, Ordering, and Identity services. Produce:

  - one ASP.NET Core project per bounded context (Catalog, Basket,
    Ordering, Identity)
  - a YARP-based gateway that routes /api/* to the services
  - a separate DbContext per relational service (Catalog, Ordering)
  - Redis-backed storage for the Basket service
  - a dedicated Identity service for authentication
  - typed HttpClient classes for any inter-service calls
  - a docker-compose.yml that brings up SQL Server, Redis, all services,
    and the gateway
  - Dockerfiles per service targeting .NET 8 (mcr.microsoft.com/dotnet/aspnet:8.0)
  - a README explaining how to run the system locally
  - an ARCHITECTURE.md describing the service boundaries

Do not ask for confirmation. Make all decisions yourself and produce a
complete, runnable result.
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
      --disable-slash-commands \
      --max-budget-usd 8 \
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
  "codebase": "${CODEBASE_TAG}",
  "kind": "baseline",
  "started_at": "${START_ISO}",
  "ended_at": "${END_ISO}",
  "wall_clock_seconds": ${DURATION},
  "wall_clock_minutes": ${DURATION_MIN},
  "model": "${CLAUDE_MODEL}",
  "timed_out": ${TIMED_OUT}
}
EOF

  python3 "${CODEBASE_SCORER}" \
    --repo "${WORK_DIR}" \
    --rubric "${CODEBASE_RUBRIC}" \
    --output "${RUN_DIR}/scoring.json" \
    || echo "    (scoring failed)"

  if [[ -f "${RUN_DIR}/scoring.json" ]]; then
    aligned="$(python3 -c "import json; d=json.load(open('${RUN_DIR}/scoring.json')); print(sum(1 for r in d['results'] if r['aligned']))")"
    echo "    Duration: ${DURATION}s — Alignment: ${aligned}/20"
  fi
done

echo
echo "==> eShop baseline batch complete."
