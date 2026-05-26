# Known per-run issues

Honest log of runs that exited cleanly but did not exercise the intended
workflow. The aggregator excludes these from the per-condition mean while
still counting them toward the *attempted runs* total and the
*skill-invocation failure rate*. The numbers and the exclusion rule are
both reported in the paper.

## refactor-skill / run-005 (2026-05-26)

- **What happened.** Exit code 0, 18 turns, 2.28 min, $0.28. Final
  result text from the model:
  *"I've encountered a technical issue - the `/refactor` skill is
  failing to execute and returns only an error message without
  creating any tasks or producing output. I've attempted to invoke
  it multiple times without success."*
- **Effect on output.** Slice 1 was left effectively unchanged; no
  microservices decomposition was produced. The mechanical scorer
  reports 9/20 because the original Slice 1 already satisfies a few
  dimensions (README present, no AllowAnyOrigin, etc.).
- **Classification.** Skill-invocation failure. Counted toward the
  10% failure rate; excluded from the alignment mean.
- **Likely cause.** Race condition in skill discovery when many
  back-to-back non-interactive sessions are launched in quick
  succession. We did not retry within this experiment because the
  experimental protocol fixes N=10 attempted runs and reporting the
  failure rate honestly is more informative than re-running until
  success.
