# A Skill-Mediated LLM Workflow for .NET Monolith Migration

This repository hosts the IEEE Access manuscript by Olariu and Alboaie
together with the full experimental harness used to produce its
empirical results. It is a controlled multi-case study of one
composition pattern: ten [Claude Code][cc] skill scripts chained into
a single end-to-end workflow for migrating .NET monoliths to
microservices.

[cc]: https://docs.claude.com/en/docs/claude-code

The paper's headline finding is reported honestly. On the primary case
study (PetRescue, .NET 10), ten repeated runs of the skill-mediated
workflow scored a mean of 12.11/20 against a pre-registered structural
rubric, while ten matched baseline runs of the raw LLM with an
explicit prompt scored 14.80/20. The raw LLM with a fully-specified
prompt *outperforms* the skill-mediated workflow on isolated
single-shot decomposition. The skills' contribution is not better
LLM output; it is the wrapper around the LLM ---  composition across
the full SDLC, persistent inter-skill artefacts, pre-commit quality
gates, and reduced prompt-engineering burden on the practitioner.
The same pattern replicates on a transfer case (Microsoft's
eShopOnWeb, .NET 8) to within 0.1 percentage points of the primary
case's gap.

## Layout

```
.
├── main_access.tex            ← IEEE Access manuscript (current)
├── cover-letter-access.tex    ← submission cover letter
├── references.bib             ← 26 entries
├── main.tex                   ← original IEEE Software draft (rejected; kept for reference)
├── cover-letter.tex           ← original cover letter (rejected; kept for reference)
├── figures/                   ← TikZ sources for the pipeline / architecture / gate figures
└── experiments/
    ├── README.md              ← experiment protocol
    ├── config.env             ← PetRescue paths and run counts
    ├── config_eshop.env       ← eShopOnWeb overrides
    ├── bootstrap.sh           ← captures runs/_environment.json
    ├── dimensions.json        ← pre-registered 20-dimension rubric (PetRescue)
    ├── dimensions_eshop.json  ← pre-registered 20-dimension rubric (eShopOnWeb)
    ├── run_refactor.sh        ← PetRescue skill-mediated runner
    ├── run_baseline.sh        ← PetRescue raw-LLM baseline runner
    ├── run_refactor_eshop.sh  ← eShopOnWeb skill-mediated runner
    ├── run_baseline_eshop.sh  ← eShopOnWeb raw-LLM baseline runner
    ├── run_security_audit.sh  ← /check_security precision/recall harness
    ├── run_full_batch.sh      ← PetRescue full-batch master
    ├── run_eshop_batch.sh     ← eShopOnWeb transfer-batch master
    ├── injection_corpus/      ← 10 vulnerable + 10 clean .cs specimens, CWE-labelled
    ├── scoring/
    │   ├── score_decomposition.py    ← PetRescue rubric verifiers (zero deps)
    │   ├── score_eshop.py            ← eShopOnWeb rubric verifiers (zero deps)
    │   ├── aggregate.py              ← mean ± stdev per phase, with exclusion support
    │   ├── inference.py              ← Welch t-test and Wilson CI (zero deps)
    │   └── VERIFIER_CHANGELOG.md     ← every patch to a mechanical verifier
    └── runs/
        ├── _environment.json         ← LLM model id, hardware, skill SHAs, slice commits
        ├── _statistics.json          ← Welch t and Wilson CI from inference.py
        ├── INTERIM_OBSERVATIONS.md   ← research-note diary
        └── KNOWN_RUN_ISSUES.md       ← runs excluded from per-condition mean
```

The bulky per-run outputs (transcripts, scoring JSONs, the rsync'd
output repositories) are not in this Git repository. They are
deposited as a single tarball at Zenodo and cited by DOI from the
manuscript.

## How to reproduce

Configuration:

  - LLM model identity:   `claude-sonnet-4-5-20250929`
  - Claude Code version:  `2.1.143`
  - Hardware:             Apple M4 Pro, 24 GB, ARM64 (any equivalent works)
  - .NET SDK:             10.0.100 (PetRescue), 8.x (eShopOnWeb)

Setup:

```bash
git clone https://github.com/florinolariuip/ieee-access-monolith-migration.git
cd ieee-access-monolith-migration/experiments

# Pull the case-study codebases at the experimental commit (commits are
# captured in runs/_environment.json):
git clone https://github.com/florinolariuip/petrescue-net-slice1.git ../petrescue-net-slice1
git clone https://github.com/dotnet-architecture/eShopOnWeb.git ../eShopOnWeb

# Capture the new environment manifest:
./bootstrap.sh
```

Reproduce the PetRescue results:

```bash
./run_full_batch.sh    # 10 skill-mediated + 10 baseline + security audit
python3 scoring/aggregate.py
python3 scoring/inference.py
```

Reproduce the eShopOnWeb transfer check:

```bash
./run_refactor_eshop.sh 3
./run_baseline_eshop.sh 3
python3 scoring/aggregate.py runs/eshop-refactor-skill runs/eshop-refactor-baseline
```

Expected wall-clock under the default configuration: ~3 hours for the
full PetRescue batch, ~60 minutes for the eShop transfer check. Token
cost per run is capped at \$5--\$8 by the harness; observed cost averaged
\$1.50 per /refactor run during the original experiment.

## How to cite

If you reproduce, extend, or build on this work, please cite both the
IEEE Access manuscript (DOI forthcoming) and this reproducibility
deposit (`CITATION.cff` in the repository root; Zenodo DOI in the
Data Availability section of the manuscript).

## License

MIT. See `LICENSE` for details.

## Contact

Florin Olariu --- `folariu@suvoda.com` --- on behalf of both authors.
