# Parse F1 gold dataset

Twenty hand-crafted synthetic resumes covering realistic patterns for the
Indian placement-market context Jobify targets. The first eight (001-008)
are straightforward; 009-020 add deliberately hard cases (mangled
two-column extraction artifacts, unconventional section headers, phone
numbers without a country code, Hinglish prose, non-tech vocabularies,
a name hidden mid-header, career gaps, long multi-role documents) so the
dataset stresses the library parser's regex/keyword heuristics and gives
the future LLM parser lane (Task 6) real signal. Each example is two
files:

- `<id>-<name-slug>.txt` — raw resume text (UTF-8, no extraction needed).
- `<id>-<name-slug>.expected.json` — expected `name`, `email`, `phone`, and
  `skills` values per the `ParsedResume` schema.

## Why text-only

The F1 gate measures the **parser's extraction quality** — not the text
extractor (pdfplumber / python-docx). Feeding raw text directly bypasses
the byte → text step so a regression in `extract_text` doesn't bleed into
the F1 numbers. Text-extraction reliability is its own gate that lives
elsewhere when needed.

## Why only four fields

`name`, `email`, `phone`, `skills` are the highest-signal fields and the
ones the regex/keyword parser handles deterministically. `experience`,
`education`, and `certifications` are extracted by noisier heuristics
(date-range scanning, degree-keyword + nearby-year). They get F1 reports
in the eval output for visibility but **do not gate CI** in v0.

The LLM lane (`LLM_EVAL_REPORT.md`) gates the same four fields at a higher
overall floor (0.90); the non-gated three stay report-only there too.

## How to score

- **Scalar fields** (`name`, `email`, `phone`): one example per case.
  Normalization:
  - `name`: case-fold + trim.
  - `email`: lowercase + trim.
  - `phone`: digits-only.

  TP = predicted matches expected. FP = predicted non-null but expected
  null (or mismatch when both non-null). FN = expected non-null but
  predicted null (or mismatch when both non-null). A mismatch counts as
  both FP and FN.

- **`skills`**: set intersection. Predicted and expected normalized via
  case-fold. TP = |predicted ∩ expected|; FP = |predicted - expected|;
  FN = |expected - predicted|.

- **Per-example F1** = `2·TP / (2·TP + FP + FN)`.

- **Per-field F1** = macro-average across examples (sum TP/FP/FN across
  examples, then F1).

- **Overall F1** = macro-average across the four gated fields.

## CI gate (v0)

- Overall F1 ≥ 0.85 (spec §13 P1 target).
- Per-field floor: `email` ≥ 0.95, `phone` ≥ 0.85, `name` ≥ 0.70,
  `skills` ≥ 0.75.

Below either gate fails the test. The spec's ≥ 0.90 launch target is met
by the **LLM lane** (`LLM_EVAL_REPORT.md`, on demand, `LLM_OVERALL_FLOOR`),
not by ratcheting this deterministic gate — the library parser measures
0.927 here with 3 documented expectation-gap FPs, so a 0.90 floor on it
would fail CI on the next legitimate hard example.

## Documented limitations (non-gated fields)

These are known, accepted gaps in the library parser's non-gated
extractors — surfaced by the harder examples in 009-020. They don't fail
CI (only `name`/`email`/`phone`/`skills` gate) but are worth tracking so
the LLM parser lane has a concrete bar to clear:

- **Certifications keyed on the literal word "certif\*"** —
  `009-020/017-unconventional-headers-dev.txt` lists two real
  certifications under a "PAPERS & BADGES" header instead of a
  "CERTIFICATIONS"-style header/keyword; `_extract_certifications` finds
  zero entries. Any resume that doesn't use the word
  "certified"/"certification" near a credential is invisible to this
  extractor, regardless of header wording.
- ~~**`_extract_skills` substring containment produces predictable false
  positives**~~ — **FIXED 2026-08-15.** `_extract_skills` now matches on
  token boundaries, so "gin" no longer fires inside
  "engineer"/"margin"/"beginning", "ember" inside "member", "ios" inside
  "Symbiosis", "scala" inside "escalation", "perl" inside "hyperlocal", nor
  "sql"/"postgres" inside "postgresql". Measured over this dataset: skills
  **FP 47 → 3**, F1 **0.795 → 0.883**, overall **0.904 → 0.927**, with TP
  (174) and FN (43) both unchanged — pure precision, no recall traded away.
  A second rule suppresses an entry whose every occurrence sits inside a
  longer match ("Spring Boot" no longer also reports "spring"); it is
  occurrence-based, so a resume writing both "Postgres" and "PostgreSQL"
  keeps both.
- **The 3 surviving `skills` FPs are gaps in the EXPECTED files, not parser
  errors** — `microservices` (001, resume says "Migrated 12 microservices"),
  and `postgres` + `pgvector` (008, resume says "Postgres pgvector."). Each
  token really is written in the resume; the hand-authored expectation omits
  it. Deliberately NOT "fixed" by editing the expectations — that would be
  tuning ground truth to flatter the parser. Revisit only with a decision on
  whether "microservices" counts as a skill and whether 008's expectation
  should list the datastores it names.
- **Non-tech vocabularies score near-zero recall on `skills`** —
  009 (FMCG sales), 013 (ops executive), 014 (school teacher), 016 (HR
  generalist), 019 (delivery ops), 020 (financial analyst — 7 of 8
  expected skills, e.g. "financial modeling"/"fp&a"/"power bi", are
  outside the dict) have skills entirely or mostly outside the curated
  tech dictionary by design; this is expected, not a bug, and is exactly
  the gap the LLM parser is meant to close (it does: 009/016/020 score
  1.000 on the LLM lane).
- **013, 014 and 019 expect NO skills (`[]`)** — so on the LLM lane any
  skill-like phrase the model extracts there ("lesson planning", "excel")
  counts as an FP even though it is in the resume text, capping those
  examples' skills F1 at 0. Whether such phrases are "skills" for
  non-tech applicants is a product decision; take it once and apply it to
  all three together. Separately, **005's expectation omits seven tools
  its own `SKILLS` block lists** (Mixpanel, Amplitude, Looker, Tableau,
  Figma, Jira, plus Confluence) and 007 omits Firebase — plain authoring
  gaps per step 3 below, worth a dataset commit that refreshes the
  baseline figures in this file, `core/CLAUDE.md`, and
  `LLM_EVAL_REPORT.md` together.

## Adding examples

1. Drop a `.txt` + `.expected.json` pair with the next ID.
2. Re-run `uv run pytest -m eval -v`. Inspect the per-example breakdown.
3. If the new example tanks a field's F1 below floor, decide: is the
   expectation wrong, or is the parser legitimately weak? Adjust either
   the floor (and document why) or the expectation.
