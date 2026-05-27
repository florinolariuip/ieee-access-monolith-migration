#!/usr/bin/env bash
# Build the Zenodo reproducibility deposit tarball.
# Produces ./zenodo-deposit-YYYYMMDD.tar.gz containing everything a
# reviewer or future researcher needs to reproduce the paper's
# empirical results under the same model identity.

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE="$(date -u +%Y%m%d)"
OUT="${HERE}/zenodo-deposit-${DATE}.tar.gz"
STAGING="$(mktemp -d)/ieee-access-deposit-${DATE}"
mkdir -p "${STAGING}"

echo "==> Staging at ${STAGING}"

# --- 1. The repository as it stands (without build artefacts) ---------------
echo "    [1/4] Repo snapshot (without LaTeX build artefacts)"
rsync -a \
  --exclude '.git' \
  --exclude '*.aux' --exclude '*.log' --exclude '*.out' \
  --exclude '*.bbl' --exclude '*.blg' --exclude '*.toc' \
  --exclude '*.synctex.gz' --exclude '*.fdb_latexmk' --exclude '*.fls' \
  --exclude '.DS_Store' \
  --exclude '__pycache__' \
  --exclude 'zenodo-deposit-*.tar.gz' \
  "${HERE}/" "${STAGING}/repo/"

# --- 2. The compiled PDFs at the deposit moment -----------------------------
echo "    [2/4] Compiled PDFs"
mkdir -p "${STAGING}/pdf"
for f in main_access.pdf cover-letter-access.pdf; do
  [[ -f "${HERE}/${f}" ]] && cp "${HERE}/${f}" "${STAGING}/pdf/"
done

# --- 3. The bulky run outputs (gitignored from the repo) --------------------
echo "    [3/4] Per-run experimental outputs"
mkdir -p "${STAGING}/runs"
if [[ -d "${HERE}/experiments/runs" ]]; then
  rsync -a \
    --exclude '_batch.pid' --exclude '_security.pid' --exclude '_batch.out' \
    --exclude '_batch.err' --exclude '_eshop_batch.out' --exclude '_eshop_batch.err' \
    --exclude '_eshop_baseline.out' --exclude '_eshop_pilot.out' \
    "${HERE}/experiments/runs/" "${STAGING}/runs/experiments-runs/"
fi

# --- 4. A README that explains the deposit ----------------------------------
echo "    [4/4] Deposit README"
cat > "${STAGING}/DEPOSIT_README.md" <<EOF
# Zenodo Deposit — IEEE Access Manuscript

Companion deposit for the manuscript by Olariu and Alboaie, submitted
to IEEE Access. Built on $(date -u +%Y-%m-%dT%H:%M:%SZ).

## Layout

\`\`\`
.
├── DEPOSIT_README.md   ← this file
├── repo/               ← the GitHub repository snapshot (without LaTeX build artefacts)
├── pdf/                ← compiled manuscript and cover letter
└── runs/               ← per-run experimental outputs (transcripts, scoring JSONs,
                         the rsync'd post-/refactor codebases per run)
\`\`\`

## How to use this deposit

1. To reproduce the paper's empirical results under the same model
   identity, follow the instructions in \`repo/README.md\`.
2. The pre-registered rubrics are in \`repo/experiments/dimensions.json\`
   (PetRescue) and \`repo/experiments/dimensions_eshop.json\` (eShop).
3. The full environment manifest is in
   \`repo/experiments/runs/_environment.json\`.
4. To re-aggregate the existing run data without re-running, run
   \`python3 repo/experiments/scoring/aggregate.py runs/experiments-runs/refactor-skill runs/experiments-runs/refactor-baseline\`.

## How to cite

If you reproduce, extend, or build on this work, please cite both the
IEEE Access manuscript and this deposit. See \`repo/CITATION.cff\`.

## License

MIT. See \`repo/LICENSE\` for details.
EOF

# --- pack -------------------------------------------------------------------
echo "==> Packing"
tar -czf "${OUT}" -C "$(dirname "${STAGING}")" "$(basename "${STAGING}")"
SIZE="$(du -h "${OUT}" | awk '{print $1}')"
echo "==> Done: ${OUT}  (${SIZE})"

echo
echo "Next steps:"
echo "  1. Log in at https://zenodo.org and click New Upload."
echo "  2. Drag-drop ${OUT}."
echo "  3. The metadata in .zenodo.json should be picked up automatically."
echo "  4. Reserve the DOI before publishing so you can cite it in main_access.tex."
echo "  5. Replace the \\TBD{Zenodo DOI} placeholder in main_access.tex with the reserved DOI."
echo "  6. Push the final commit and publish the deposit."
