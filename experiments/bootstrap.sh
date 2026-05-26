#!/usr/bin/env bash
# Capture the experiment environment once, into runs/_environment.json.
# This file is cited verbatim from the paper's §Methodology — every value
# here must be reproducible exactly.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.env"

mkdir -p "${RUNS_DIR}"
OUT="${RUNS_DIR}/_environment.json"

# Capture skill commit hashes
declare -a SKILL_HASHES=()
for skill_dir in "${SKILLS_DIR}"/*/; do
  skill_name="$(basename "${skill_dir}")"
  if [[ -f "${skill_dir}/SKILL.md" ]]; then
    # Hash the SKILL.md content directly so we have a stable identifier even
    # if the skill isn't in a git repo.
    skill_hash="$(shasum -a 256 "${skill_dir}/SKILL.md" | awk '{print $1}')"
    SKILL_HASHES+=("\"${skill_name}\": \"${skill_hash}\"")
  fi
done
SKILLS_JSON="$(IFS=','; echo "${SKILL_HASHES[*]}")"

# Capture slice commits
slice_commit() {
  local repo="$1"
  if [[ -d "${repo}/.git" ]]; then
    git -C "${repo}" rev-parse HEAD 2>/dev/null || echo "no-git-history"
  else
    echo "not-a-git-repo"
  fi
}

cat > "${OUT}" <<EOF
{
  "captured_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "machine": {
    "uname": "$(uname -a)",
    "cpu_brand": "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)",
    "ram_gb": $(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1073741824)),
    "arch": "$(uname -m)"
  },
  "toolchain": {
    "claude_cli_version": "${CLAUDE_CLI_VERSION:-unknown}",
    "claude_model": "${CLAUDE_MODEL}",
    "dotnet_sdk": "$(dotnet --version 2>/dev/null || echo not-installed)",
    "docker": "$(docker --version 2>/dev/null || echo not-installed)",
    "git": "$(git --version 2>/dev/null | awk '{print $3}' || echo not-installed)"
  },
  "skills": { ${SKILLS_JSON} },
  "slices": {
    "slice1_commit":            "$(slice_commit "${SLICE1_REPO}")",
    "slice2_commit":            "$(slice_commit "${SLICE2_REPO}")",
    "slice1_refactored_commit": "$(slice_commit "${SLICE1_REFACTORED_REPO}")"
  },
  "run_counts": {
    "refactor_runs":   ${REFACTOR_RUNS},
    "baseline_runs":   ${BASELINE_RUNS},
    "full_cycle_runs": ${FULL_CYCLE_RUNS}
  }
}
EOF

echo "Environment captured: ${OUT}"
cat "${OUT}"
