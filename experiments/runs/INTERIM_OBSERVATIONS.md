# Interim observations (live, while the batch runs)

Working notes for the §Results and §Discussion sections, captured as the
data arrives. Not for publication verbatim; used by the human author when
drafting prose.

## 1. Skill-mediated runs cluster tightly at 11–13 / 20

Nine successful runs scored: 11, 11, 13, 12, 13, 12, 12, 12, 13.
Mean 12.11 / 20 (60.6%), stdev 0.78 dimensions, range 11–13.
Wall-clock mean ≈ 9.4 min, stdev ≈ 1.5 min (excluding the failed run).

The tightness of the cluster matters for the paper: the workflow is
*consistent* on the dimensions it satisfies (10 dimensions are aligned
in every successful run) and *consistently divergent* on the dimensions
it doesn't (7 dimensions are aligned in zero runs).

## 2. Skill-invocation failure rate ≈ 10%

run-005 cleanly exited but the model reported "the /refactor skill is
failing to execute and returns only an error message". It produced no
decomposition. Scored 9/20 against the original (unchanged) Slice 1.

The paper reports this as a 10% (1/10) skill-invocation failure rate,
flagged in `KNOWN_RUN_ISSUES.md`. Excluded from the alignment mean,
counted toward attempted runs.

This is a real failure mode of skill-based workflows and is genuinely
interesting data.

## 3. Baseline (no-skill) appears to outperform skill-mediated

First baseline run scored 15/20 in 9.37 min — **higher** than any of
the nine successful skill-mediated runs.

Reason: the baseline prompt deliberately enumerates the deliverables
(per-service projects, YARP gateway, HasDefaultSchema, typed
HttpClients, Dockerfiles targeting .NET 10, README, ARCHITECTURE.md)
so that the comparison is between skill-mediated workflow and a
fully-specified raw-LLM instruction, not against an under-specified
one. The methodology section discloses this explicitly.

**Implication for the paper.** The skill-mediated workflow does *not*
outperform a maximally-prompted raw LLM on isolated structural alignment.
That is a fair, honest finding and it reframes the value proposition:

- The skills' contribution is **not** in producing better individual
  decompositions in a single shot.
- The skills' contribution is in:
  1. **Composability** — the same ten skills span the full SDLC
     (requirements → architecture → refactor → test → review →
     security → publish), not just decomposition.
  2. **Artefact-mediated state** — persistent intermediate files
     (REQUIREMENTS.md, ARCHITECTURE.md, REVIEW.md, SECURITY.md)
     that are auditable and that subsequent skills consume.
  3. **Pre-commit quality gates** — /publish refuses to commit
     unless REVIEW.md and SECURITY.md gate-out.
  4. **Lowered prompt-engineering effort** — the user types
     "/refactor", not a 200-word prompt enumerating every
     deliverable. The baseline result quantifies how much
     prompt engineering would otherwise be required.
- The skills also impose a **measurable cost**: 10% invocation
  failure rate, 9–10 min wall-clock per skill.

This recasting aligns with Lenuta's intuition: "AI doar completează
framework-ul" — the LLM does the substantive work; the skills are the
framework that makes that work reproducible, gated, and ergonomic.

## 4. Dimensions that are always-aligned across skill-mediated runs

D03 (separate projects), D04 (no cross-project refs), D05 (DbContexts),
D08 (no cross-schema FKs), D11 (REST conventions), D14 (no hardcoded
secrets), D15 (AllowedHosts), D17 (no AllowAnyOrigin), D18 (root
README), D19 (per-service README — actually a false positive from
sidecar/.venv noise, will tighten verifier and re-score before final
submission), D20 (ARCHITECTURE.md).

## 5. Dimensions that are never-aligned across skill-mediated runs

- D01 (specific Animals/Adoptions/Donations boundaries): /refactor
  consistently picks different bounded contexts (AnimalService,
  MedicalService, AdoptionService, AnalyticsService, DocumentService).
  Different valid choice, not an error.
- D06 (HasDefaultSchema): /refactor uses database-per-service via
  separate connection strings, not schema isolation. Different valid
  approach.
- D07 (Search Path): consequence of (6) — no Search Path needed.
- D09 (typed HttpClient AddHttpClient<>): /refactor uses inline
  HttpClient or different DI pattern.
- D10 (/internal/ routes): /refactor exposes internal endpoints
  on a separate port instead.
- D12 (specific ports 5101–5103): /refactor uses 5000–5004.
- D13 (.NET 10 Dockerfiles): /refactor consistently targets .NET 8
  (LTS) instead of .NET 10. This may actually be the *better*
  choice for production.
- D16 (loopback/internal-key filter): /refactor relies on Docker
  network isolation instead of application-layer filtering.

The pattern is clear: the skill consistently produces a *different
but coherent* decomposition than the manual reference. The rubric
was designed against the manual reference's specific choices, so
divergence shows up as mis-alignment. This is the §Results headline.

## 6. Baseline (no-skill) over the full N=10 run

| Statistic | Value |
|---|---|
| N attempted | 10 |
| N scored | 10 |
| Mean alignment | 14.80 / 20 (74.0%) |
| Stdev alignment | 0.64 / 20 (3.2%) |
| Range | 14–16 / 20 |
| Mean wall-clock | 8.90 min |
| Stdev wall-clock | 1.08 min |
| Skill-invocation failures | 0 / 10 |

Per-dimension comparison (skill vs baseline, alignment rate):

| Dim | Skill | Baseline | Note |
|---|---|---|---|
| D01 specific contexts | 0%  | 0%  | both diverge from Slice 2 names |
| D02 YARP gateway     | 56% | 100% | baseline always uses YARP |
| D03 separate projects| 100%| 100% | table stakes |
| D04 no cross-refs    | 100%| 90% | both keep services decoupled |
| D05 DbContexts       | 100%| 100% | table stakes |
| D06 HasDefaultSchema | 11% | 90% | skill prefers DB-per-service |
| D07 Search Path      | 0%  | 0%  | neither uses Search Path |
| D08 no x-schema FK   | 100%| 100% | table stakes |
| D09 typed HttpClient | 0%  | 80% | skill never registers typed clients |
| D10 /internal/ route | 0%  | 20% | architectural divergence |
| D11 REST endpoints   | 100%| 100% | table stakes |
| D12 ports 5101–5103  | 0%  | 0%  | both pick 5000-range |
| D13 .NET 10 in Docker| 44% | 100% | skill prefers .NET 8 LTS |
| D14 no hardcoded sec | 100%| 100% | table stakes |
| D15 AllowedHosts     | 100%| 100% | table stakes |
| D16 loopback filter  | 0%  | 0%  | neither implements it |
| D17 no AnyOrigin     | 100%| 100% | table stakes |
| D18 root README      | 100%| 100% | table stakes |
| D19 per-service docs | 100%| 100% | table stakes (some sidecar noise) |
| D20 ARCHITECTURE.md  | 100%| 100% | table stakes |

Four dimensions account for almost the entire gap: D02 (YARP), D06
(HasDefaultSchema), D09 (typed HttpClient), D13 (.NET 10). On those
four, the baseline matches the prompt's enumeration and the skill
makes a different — consistent and defensible — architectural choice.

## 7. Security gates: high recall, low specificity

Twenty-file matched-pair injection corpus, one `/check_security`
invocation per file in isolation.

| Metric | Value |
|---|---|
| True positives  (TP) | 10 |
| False negatives (FN) |  0 |
| True negatives  (TN) |  1 |
| False positives (FP) |  9 |
| Recall              | 1.00 (100%) |
| Precision           | 0.526 (52.6%) |
| Specificity         | 0.10 (10%) |

The skill catches every injected vulnerability across all ten CWE
classes. It also flags 9 of 10 clean specimens. The downstream
consequence is that a security engineer still has to triage every
high-severity finding emitted by `/check_security` — roughly half
will be real, the other half conservative-by-default warnings.

This is the strongest single piece of evidence for Lenuta's reframing:
these are automated DevOps hygiene checks (high recall, conservative
specificity), not a substitute for formal security review.
