# Parse F1 gold dataset

Twenty hand-crafted synthetic resumes covering realistic patterns for the
Indian placement-market context Jobify targets. The first eight (001-008)
are straightforward; 009-020 add deliberately hard cases (mangled
two-column extraction artifacts, unconventional section headers, phone
numbers without a country code, Hinglish prose, non-tech vocabularies,
a name hidden mid-header, career gaps, long multi-role documents) so the
dataset stresses the library parser's regex/keyword heuristics and gives
the LLM parser lane real signal. Each example is two files:

- `<id>-<name-slug>.txt` — raw resume text (UTF-8, no extraction needed).
- `<id>-<name-slug>.expected.json` — expected values for all eight
  `ParsedResume` fields (see "Fields" below).

A second, **real** set lives outside the repo — see "Real set" at the end.

## Why text-only

The F1 gate measures the **parser's extraction quality** — not the text
extractor (pdfplumber / python-docx). Feeding raw text directly bypasses
the byte → text step so a regression in `extract_text` doesn't bleed into
the F1 numbers. The real set is the exception: it goes through the
production extractor on purpose, because that is where layout garbling
lives.

## Fields

Two kinds, scored the same way but treated differently by the gate:

| Field | Kind | Scored as | Gate |
|---|---|---|---|
| `name` | scalar | case-fold + trim | yes |
| `email` | scalar | lowercase + trim | yes |
| `phone` | scalar | digits-only | yes |
| `skills` | set | case-fold each item | yes |
| `languages` | set | case-fold each item | report-only |
| `experience` | set of keys | `company\|title` | report-only |
| `education` | set of keys | `institution\|degree` | report-only |
| `certifications` | set of keys | `name` | report-only |

Structured-list keys are normalised (case-fold, whitespace collapse,
trailing `.,;:` stripped; a missing part is `?`) and then matched
**exactly**. Organisation parts (`company`, `institution`) additionally
drop a trailing `, <location>` or `(qualifier)` on **both** sides, because
the prompt says copy verbatim ("Anna University, Chennai") while a human
authoring gold writes the organisation alone — measured 2026-09-07, that
one gap was most of the education FP/FN pairs. Author gold either way. Gold entries are authored to the resume's own wording and the
LLM prompt says copy verbatim, so exact-after-normalisation is the
contract. Fuzzy matching was rejected: every threshold is an argument, and
it hides exactly the sloppiness the number should expose. Dates are not
scored in v1.

**Report-only** fields (added 2026-09-07) never enter `overall`, which
stays the macro mean of the four gated fields so the 0.85 (CI) and 0.90
(LLM acceptance) floors keep their meaning. On the **LLM lane** they gate
individually since 2026-09-08 (`LLM_PER_FIELD_FLOORS`: languages ≥ 0.75,
experience ≥ 0.95, education ≥ 0.90, certifications ≥ 0.90), set from the
prompt-v3 baseline on `gemini-3.1-flash-lite` with margin. The library
lane prints them and gates nothing on them (it cannot extract them).

## The skills rule (product decision, 2026-09-07)

Applied to every expected file at once. A **skill** is a noun phrase naming
a competency, tool, technology, or domain the resume states the person has
or did — in any vocabulary, not just software:

- tools/technologies: "MS Office", "Tally", "Python", "AWS"
- competencies stated in prose or lists: "route planning", "lesson
  planning", "stock reconciliation", "team management" (when the text says
  they managed a team)
- domains: "logistics operations", "FMCG sales", "financial modeling"

Not skills: human languages (→ `languages`), trait adjectives
("hardworking", "team player"), job titles, degrees, hobbies. Items keep
the granularity the resume uses ("Tailwind CSS", not "Tailwind"; "REST
APIs", not "REST"). Earlier versions of this dataset expected `[]` for
the non-tech resumes (013, 014, 019) and omitted tools that 005/007 list
outright; both were fixed under this rule, and the LLM lane's "false
positives" on those rows were the parser being right.

## How to score

- **Scalar fields**: one example per case. TP = predicted matches
  expected. FP = predicted non-null but expected null (or mismatch when
  both non-null). FN = expected non-null but predicted null (or mismatch).
  A mismatch counts as both FP and FN.
- **Set fields** (`skills`, `languages`, and the three structured lists
  via their keys): TP = |predicted ∩ expected|; FP = |predicted −
  expected|; FN = |expected − predicted|.
- **Per-field F1** = `2·TP / (2·TP + FP + FN)`, pooled across examples.
- **Overall F1** = macro-average across the four **gated** fields.
- Every run also prints a **token diff** per set field (FP tokens, FN
  tokens) for the synthetic set, so any FP can be checked against the
  resume text. A token absent from the text is an invented entry — the
  one error class the gate exists to catch. Everything else is a
  wording/granularity or gold-authoring question.

## CI gate (v0)

- Overall F1 ≥ 0.85 (spec §13 P1 target) — library parser, deterministic.
- Per-field floor: `email` ≥ 0.95, `phone` ≥ 0.85, `name` ≥ 0.70,
  `skills` ≥ 0.75 — **except the library lane's `skills` floor is 0.70**
  since 2026-09-07: the skills rule above added non-tech competencies and
  prose-named tools the dictionary parser cannot see by design, taking its
  skills F1 0.883 → 0.721 with FP unchanged (pure recall it never had). The
  floor sits just under the measured value so the deterministic gate still
  catches regressions (an FP explosion trips it) without pretending the
  library parser meets a bar only the LLM lane is built for. The LLM lane
  keeps 0.75.

Below either gate fails the test. The spec's ≥ 0.90 launch target is met
by the **LLM lane** (`LLM_EVAL_REPORT.md`, on demand, `LLM_OVERALL_FLOOR`),
not by ratcheting this deterministic gate — the library parser measures
in the low 0.9s here with documented expectation-gap FPs, so a 0.90 floor
on it would fail CI on the next legitimate hard example.

## Documented limitations (library parser)

Known, accepted gaps in the library parser's extractors — surfaced by the
harder examples in 009-020. They don't fail CI but are worth tracking so
the LLM lane has a concrete bar to clear:

- **Certifications keyed on the literal word "certif\*"** —
  `017-unconventional-headers-dev.txt` lists two real certifications under
  a "PAPERS & BADGES" header; `_extract_certifications` finds zero. Any
  resume that doesn't use the word "certified"/"certification" near a
  credential is invisible to this extractor, regardless of header wording.
- ~~**`_extract_skills` substring containment produces predictable false
  positives**~~ — **FIXED 2026-08-15.** `_extract_skills` now matches on
  token boundaries, so "gin" no longer fires inside
  "engineer"/"margin"/"beginning", "ember" inside "member", "ios" inside
  "Symbiosis", "scala" inside "escalation", "perl" inside "hyperlocal", nor
  "sql"/"postgres" inside "postgresql". A second rule suppresses an entry
  whose every occurrence sits inside a longer match ("Spring Boot" no
  longer also reports "spring"); it is occurrence-based, so a resume
  writing both "Postgres" and "PostgreSQL" keeps both.
- **Non-tech vocabularies score near-zero recall on `skills`** —
  009 (FMCG sales), 013 (ops executive), 014 (school teacher), 016 (HR
  generalist), 019 (delivery ops), 020 (financial analyst) have skills
  entirely or mostly outside the curated tech dictionary by design. This
  is expected, not a bug, and is exactly the gap the LLM parser closes
  (those rows score at or near 1.000 on the LLM lane).
- **`languages` is never extracted** by the library parser (no
  heuristic); it scores 0 recall there and is report-only anyway.

## Adding examples

1. Drop a `.txt` + `.expected.json` pair with the next ID. Author the
   expectation from the **text**, all eight keys, verbatim wording, under
   the skills rule above. Drafting from the LLM parser's output is fine as
   a typing aid, but verify every entry against the text — never tune
   ground truth to flatter the parser.
2. Re-run `uv run pytest -m eval -v -s`. Inspect the per-example breakdown
   and the token diff.
3. If the new example tanks a field's F1 below floor, decide: is the
   expectation wrong, or is the parser legitimately weak? Adjust either
   the floor (and document why) or the expectation.

## Real set (local only)

Twelve real applicant resumes (9 PDF, 3 DOCX) live in `sample_resume/` at
the repo root — **gitignored, never committed** (PII). Each has a
`<name>.expected.json` beside it authored under the same rule. Both eval
lanes load the folder when it exists (override with
`JOBIFY_PARSE_EVAL_REAL_DIR`) and print **aggregate counts only** for it;
CI and other machines see the synthetic set alone. Its text comes from the
production `extract_text`, so it also exercises the byte → text step —
one of the twelve extracted letter-spaced ("G a n e s h") from pypdf until
the 2026-09-07 garble check learned to hand such files to pdfminer.
