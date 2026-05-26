# Security Injection Corpus

This corpus measures `/check_security`'s precision and recall on **known**
inputs. It is the empirical backbone of the §Ablation / Failure Modes
discussion in the revised paper — specifically, it answers Lenuta's question:
*"who verifies the remediation is correct, were injection tests done, false
positive checks?"*

## Structure

```
injection_corpus/
├── README.md
├── true_positives/   ← each file has exactly one labelled vulnerability
│   ├── 01_sql_injection.cs
│   ├── 02_hardcoded_secret.cs
│   ├── 03_overpermissive_cors.cs
│   ├── 04_open_redirect.cs
│   ├── 05_missing_authz.cs
│   ├── 06_xxe.cs
│   ├── 07_path_traversal.cs
│   ├── 08_insecure_deserialization.cs
│   ├── 09_weak_crypto.cs
│   └── 10_jwt_no_verification.cs
├── true_negatives/   ← clean files that should NOT be flagged
│   ├── 01_parameterised_query.cs
│   ├── 02_config_from_env.cs
│   ├── 03_strict_cors.cs
│   ├── 04_validated_redirect.cs
│   ├── 05_authz_attribute.cs
│   ├── 06_safe_xml_reader.cs
│   ├── 07_canonical_path.cs
│   ├── 08_typed_dto.cs
│   ├── 09_strong_crypto.cs
│   └── 10_jwt_verified.cs
└── labels.csv        ← per-file vuln class and CWE for the metrics report
```

Each true-positive file is the minimal-reproduction of one vulnerability
class. The matched true-negative is the same scenario, fixed properly. This
matched-pair design controls for unrelated language features.

## How `run_security_audit.sh` uses it

1. Copies one file at a time into a sandboxed scratch dir.
2. Invokes `/check_security` non-interactively against that single file.
3. Parses the produced `SECURITY.md` for `Critical` or `High` findings.
4. Records `flagged ∈ {true, false}` per file.
5. Computes precision = TP / (TP + FP), recall = TP / (TP + FN),
   specificity = TN / (TN + FP) over the full corpus.

## Why a 10×10 corpus and not more?

Power vs. cost trade-off. Each audit run costs ~1 minute and ~$0.10 in tokens.
20 files = ~20 minutes and a few dollars per full pass. This gives confidence
intervals that are tight enough to surface gross precision/recall gaps but
small enough to re-run if we discover a corpus bug.

If reviewers ask for more, the corpus extends linearly.

## Labels

See `labels.csv` for the (file, CWE, severity, description) tuple per
specimen. The CWE mapping makes the corpus auditable against a public
standard — anyone can verify these are real, well-known vulnerability
classes, not strawmen.
