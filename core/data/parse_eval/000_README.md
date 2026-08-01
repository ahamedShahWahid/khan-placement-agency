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

When the LLM parser ships, all seven fields will gate.

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

Below either gate fails the test. Ratchet upward as the parser improves —
spec target is ≥ 0.90 before launch.

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
- **`_extract_skills` substring containment produces predictable false
  positives on common English words/proper nouns** (e.g. "gin" inside
  "engineer"/"engineering"/"margin"/"beginning", "ember" inside "member",
  "ios" inside "Symbiosis", "scala" inside "escalation", "perl" inside
  "hyperlocal", "sql"/"postgres" as substrings of "postgresql"). Already
  present in the original eight examples' FP counts; 009-020 make it more
  visible. The `skills_dict.py` module header tracks the fix
  (word-boundary matching) as `TODO(P3-llm-parser)`.
- **Non-tech vocabularies score near-zero recall on `skills`** —
  009 (FMCG sales), 013 (ops executive), 014 (school teacher), 016 (HR
  generalist), 019 (delivery ops), 020 (financial analyst — 7 of 8
  expected skills, e.g. "financial modeling"/"fp&a"/"power bi", are
  outside the dict) have skills entirely or mostly outside the curated
  tech dictionary by design; this is expected, not a bug, and is exactly
  the gap the LLM parser is meant to close.

## Adding examples

1. Drop a `.txt` + `.expected.json` pair with the next ID.
2. Re-run `uv run pytest -m eval -v`. Inspect the per-example breakdown.
3. If the new example tanks a field's F1 below floor, decide: is the
   expectation wrong, or is the parser legitimately weak? Adjust either
   the floor (and document why) or the expectation.
