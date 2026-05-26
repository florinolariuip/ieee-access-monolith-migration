# PetRescue Pipeline — Experiment Harness

This folder contains the empirical apparatus for the revised paper. Everything
here is intended to ship with the manuscript as supplementary material (Zenodo
deposit), so that the experiment is reproducible under the same configuration.

The structure of the experiment is laid out in the revision plan at
`~/.claude/plans/pure-wondering-wadler.md`.

## Layout

```
experiments/
├── README.md                     ← this file — protocol and how to reproduce
├── config.env                    ← model id, paths, run counts (single source of truth)
├── dimensions.yaml               ← the 20-dimension rubric, pre-registered
├── run_refactor.sh               ← invokes the skill-mediated pipeline N times
├── run_baseline.sh               ← invokes raw Claude (no skills) N times — for comparison
├── run_security_audit.sh         ← runs /check_security against the injection corpus
├── scoring/
│   ├── score_decomposition.py    ← scores a refactored repo against the 20 dimensions
│   ├── aggregate.py              ← rolls per-run scores into mean ± stdev CSV
│   └── helpers.py                ← shared file-walking, naming heuristics
├── injection_corpus/             ← deliberately-vulnerable snippets for §Security precision/recall
│   ├── README.md
│   ├── true_positives/           ← files that SHOULD be flagged (one vuln class per file)
│   └── true_negatives/           ← clean files that should NOT be flagged
└── runs/                         ← outputs (gitignored; uploaded to Zenodo as a tarball)
    ├── refactor-skill/
    │   ├── run-001/
    │   │   ├── transcript.log
    │   │   ├── output_repo/      ← snapshot of the AI's decomposition
    │   │   ├── timing.json       ← wall-clock, token counts
    │   │   └── scoring.json      ← per-dimension verdicts
    │   └── ...
    ├── refactor-baseline/        ← same monolith, raw Claude with no skill scripts
    └── security/
        └── precision_recall.json
```

## Reproducibility — the pieces that have to be pinned

These get written into `config.env` and quoted in the paper's §Methodology:

- **LLM model identity** — exact dated alias, e.g. `claude-sonnet-4-5-20250929`
- **Claude Code version** — `claude --version` at experiment time
- **Skill version** — git commit hash for each `~/.claude/skills/<skill>/SKILL.md`
- **Hardware** — `uname -a`, `sysctl -n machdep.cpu.brand_string`, RAM, .NET SDK
- **Slice 1 commit** — the git SHA the experiment runs against
- **Run count** — 10 for `/refactor`, 5 for the full feature cycle
- **Temperature / settings** — Claude Code's defaults are used; recorded verbatim

## How to reproduce

Pre-flight (one time):

```bash
cd /Users/florinolariu/Downloads/ieee-software-paper/experiments
./bootstrap.sh           # captures hardware + tool versions into runs/_environment.json
```

Then for each phase:

```bash
./run_refactor.sh        # 10 skill-mediated runs of /refactor
./run_baseline.sh        # 10 raw-LLM baseline runs
./run_security_audit.sh  # precision/recall on the injection corpus
python3 scoring/aggregate.py  # produce summary CSVs for the paper
```

Each script is idempotent at the run-id granularity — re-running creates a new
`run-NNN/` directory; it never overwrites prior data.

## What this answers in the paper

| Section | Data this folder produces |
|---|---|
| §Methodology — model & hardware | `runs/_environment.json` |
| §Methodology — run protocol | `config.env` |
| §Evaluation — productivity figures | `runs/refactor-skill/*/timing.json` aggregated to mean ± stdev |
| §Evaluation — 20-dimension scoring | `runs/refactor-skill/*/scoring.json` aggregated |
| §Baseline | `runs/refactor-baseline/*/scoring.json` |
| §Ablation — security checks | `runs/security/precision_recall.json` |

## What this folder is NOT

- It is not the place to make claims. Numbers go into the paper after aggregation.
- It is not the place for narrative. All prose belongs in `main.tex`.
- It is not under-version-controlled. `runs/` is gitignored. Final tarball goes to
  Zenodo and is cited by DOI in the paper.
