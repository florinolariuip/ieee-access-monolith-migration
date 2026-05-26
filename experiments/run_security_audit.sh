#!/usr/bin/env bash
# Run /check_security against the injection corpus and compute precision/recall.
# Each file in injection_corpus/true_positives/ has exactly one labelled vuln;
# each file in true_negatives/ should NOT be flagged.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

CORPUS="${SCRIPT_DIR}/injection_corpus"
PHASE_DIR="${RUNS_DIR}/security"
mkdir -p "${PHASE_DIR}"

if [[ ! -d "${CORPUS}/true_positives" ]] || [[ ! -d "${CORPUS}/true_negatives" ]]; then
  echo "ERROR: injection corpus not built yet. See ${CORPUS}/README.md" >&2
  exit 1
fi

echo "==> Security precision/recall harness"
echo "    Corpus:       ${CORPUS}"
echo "    Output:       ${PHASE_DIR}"
echo

# We invoke /check_security once per file in the corpus. The skill produces
# SECURITY.md. We then parse it for findings and compare to the label file.

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${PHASE_DIR}/audit-${RUN_ID}"
mkdir -p "${RUN_DIR}"

audit_file() {
  local input="$1"
  local label="$2"      # "TP" (must be flagged) or "TN" (must not)
  local sandbox
  sandbox="$(mktemp -d)"
  cp "${input}" "${sandbox}/Program.cs"

  (
    cd "${sandbox}"
    gtimeout 300 claude \
      --print \
      --model "${CLAUDE_MODEL}" \
      --permission-mode acceptEdits \
      "Use /check_security to audit the .cs file in this directory. Produce SECURITY.md as usual." \
      > /dev/null 2>&1 || true
  )

  local flagged=false
  if [[ -f "${sandbox}/SECURITY.md" ]]; then
    if grep -qiE "critical|high" "${sandbox}/SECURITY.md"; then
      flagged=true
    fi
  fi

  local basename
  basename="$(basename "${input}")"
  cp "${sandbox}/SECURITY.md" "${RUN_DIR}/${label}-${basename%.cs}.SECURITY.md" 2>/dev/null || true
  rm -rf "${sandbox}"
  echo "${label},${basename},${flagged}"
}

RESULTS="${RUN_DIR}/raw.csv"
echo "label,file,flagged" > "${RESULTS}"

for f in "${CORPUS}/true_positives"/*.cs; do
  [[ -f "${f}" ]] || continue
  audit_file "${f}" "TP" >> "${RESULTS}"
done

for f in "${CORPUS}/true_negatives"/*.cs; do
  [[ -f "${f}" ]] || continue
  audit_file "${f}" "TN" >> "${RESULTS}"
done

# Compute precision / recall.
python3 - "${RESULTS}" "${RUN_DIR}/precision_recall.json" <<'PY'
import csv, json, sys
raw, out = sys.argv[1], sys.argv[2]
tp = fp = tn = fn = 0
with open(raw) as f:
    next(f)  # header
    for row in csv.reader(f):
        label, _file, flagged = row
        flagged = flagged.lower() == "true"
        if label == "TP":
            if flagged: tp += 1
            else: fn += 1
        elif label == "TN":
            if flagged: fp += 1
            else: tn += 1
prec = tp / (tp + fp) if (tp + fp) else None
rec  = tp / (tp + fn) if (tp + fn) else None
spec = tn / (tn + fp) if (tn + fp) else None
result = {
    "tp": tp, "fp": fp, "tn": tn, "fn": fn,
    "precision": round(prec, 3) if prec is not None else None,
    "recall":    round(rec, 3)  if rec  is not None else None,
    "specificity": round(spec, 3) if spec is not None else None,
}
open(out, "w").write(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
PY

echo
echo "==> Security audit complete: ${RUN_DIR}"
