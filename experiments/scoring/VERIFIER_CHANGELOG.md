# Verifier Changelog

The rubric in `dimensions.json` is **pre-registered and frozen**. The
verifier *implementations* in `score_decomposition.py` may be patched to fix
mechanical bugs (regexes that don't match the rubric statement) but never to
change what the rubric checks for. This file records every such fix.

## Principle

A change qualifies as a "bug fix" only if:

1. The rubric statement remains unchanged.
2. The previous implementation produced a result inconsistent with the
   rubric's plain-English statement on at least one observed input.
3. The new implementation produces the *intended* answer (per the rubric)
   on both the offending input and a regression suite.

A change that raises scores without satisfying (2) is rubric tuning, not a
bug fix, and is not permitted.

---

## 2026-05-26 — D05 (distinct DbContext classes)

**Rubric (unchanged):** *Each service owns a distinct DbContext class.*

**Bug:** The previous regex `class\s+\w+DbContext\s*:\s*DbContext` required
the class **name** to contain "DbContext". Pilot run-001 produced classes
named `AnimalServiceContext`, `MedicalServiceContext`, etc., which inherit
from `DbContext` but do not contain "DbContext" in their name. The verifier
reported 0 distinct DbContexts even though three were present.

**Fix:** Relax the pattern to `class\s+(\w+)\s*:\s*DbContext\b` — match any
class that **inherits from `DbContext`**, regardless of its own name. Capture
the class name for a uniqueness check so two services declaring identically-
named contexts (which would not be "distinct") still fail.

**Regression check:**

| Input | Old score | New score | Expected |
|---|---|---|---|
| Slice 1 Refactored | 0 | 3 (`AnimalsDbContext`, `MedicalDbContext`, etc.) | aligned ✓ |
| run-001 (pilot) | 0 | 3 (`AnimalServiceContext`, `MedicalServiceContext`, …) | aligned ✓ |
| Empty repo | 0 | 0 | not aligned ✓ |
