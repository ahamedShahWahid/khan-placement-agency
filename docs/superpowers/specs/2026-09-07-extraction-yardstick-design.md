# Extraction yardstick — design

**Date:** 2026-09-07 · **Status:** approved (brainstorm), implementing
**Parent:** "Better extraction at a chosen price" — three sub-projects in
dependency order: (1) this yardstick, (2) extraction quality + model choice,
(3) messy input. This spec covers (1) only.

## Why

The parse-F1 gate scores four fields (name, email, phone, skills) against 20
synthetic resumes. Three of those resumes (013, 014, 019 — ops executive,
teacher, delivery lead) expect `skills: []`, so a parser that extracts
"route planning" for a delivery lead is *penalised*. Experience, education and
certifications are extracted by the LLM parser and embedded into the applicant
vector (60 % of the match score) but never scored. A 2026-09-07 three-model
comparison (2.5 Flash, 3.1 Flash-Lite, 3.5 Flash-Lite) tied on every gated
field; all differences were on the empty-expectation rows. "Better
extraction" is therefore invisible to our own measurement, and in one
direction penalised. Nothing in sub-projects (2) or (3) can be claimed until
this is fixed.

## What it delivers

1. **Gold expectations for every parsed field** — `name`, `email`, `phone`,
   `skills`, `experience`, `education`, `certifications`, plus a new
   `languages` field — on the synthetic 20 and on a local-only real set.
2. **A skills rule** (product decision, applied to all files at once): a
   skill is a noun phrase naming a competency, tool, or domain the resume
   states the person has or did, in any vocabulary — "route planning",
   "MS Office", "team management" when the text says they managed a team.
   Spoken/written human languages go to `languages`, never `skills`. Trait
   adjectives ("hardworking") are excluded. Gold entries are authored to the
   resume's own wording (the prompt says copy verbatim).
3. **Scoring for the structured lists** — normalised exact match on a key:
   experience `company|title`, education `institution|degree`, certifications
   `name`, languages as a set. Case-fold + whitespace collapse; a missing part
   is `?`. Set F1 like skills. Dates are not scored in v1 (free-form strings
   by design). Fuzzy matching and model-as-judge were rejected: thresholds are
   arguments, and the thing under test is the model.
4. **Gating unchanged.** The four existing fields and floors gate; `overall`
   stays the macro mean of those four so the 0.85 / 0.90 numbers keep their
   meaning. New fields are **report-only** for the first measured cycle;
   floors are set from the measured baseline in a follow-up, never before.
5. **Real set, local only.** Twelve real applicant resumes (9 PDF, 3 DOCX) in
   `sample_resume/` (gitignored — PII). The eval loads them via
   `extract_text` when the folder exists and skips when absent, so CI and
   other machines see only the synthetic 20. Reports print **aggregate counts
   only** for the real set — never token diffs, names, or employers.
6. **Per-model comparison in one command** —
   `JOBIFY_PARSE_EVAL_MODELS=a,b,c` runs the LLM lane per model and prints a
   model × field table for both sets. The gate applies to the first model only
   (the production default); the rest are informational.
7. **Gemini 3.x thinking config** — 3.x models reject
   `thinking_budget=0` (`400 INVALID_ARGUMENT`, probed 2026-09-07) and want
   `thinking_level="minimal"`. One shared helper picks by model prefix; parser
   and explainer both use it, so a model switch is config-only again.
8. **Letter-spaced PDF fix** — one real sample extracted as 1,651
   single-character tokens ("G a n e s h"); pypdf's output cleared the 50-char
   "garbled" threshold so pdfminer (which reads it cleanly, 7 % single-char
   tokens) never ran. The garbled check also triggers on single-char-token
   ratio and prefers the extractor with the lower ratio.

## Not in scope

Prompt rewording for skills recognition, model selection, deriving
`years_experience` from the timeline, OCR / vision for image-only PDFs
(none of the 12 real samples is image-only), fuzzy entry matching, scoring
dates.

## Gold authoring method

Draft every expected file from the current production parser (2.5 Flash)
output, then **verify every entry against the resume text by hand** and
correct; the draft is a typing aid, not ground truth. Record deviations from
the draft so the review shows where the model was wrong. Real-set expected
files live beside the documents in the ignored folder.

## Acceptance

- `uv run pytest -m eval` (library lane) still passes at the same floors and
  additionally prints the four report-only fields.
- `JOBIFY_PARSE_EVAL_PARSER=llm JOBIFY_PARSE_EVAL_MODELS=gemini-2.5-flash,gemini-3.1-flash-lite,gemini-3.5-flash-lite …`
  prints the comparison table for synthetic and (when present) real sets.
- `LLM_EVAL_REPORT.md` refreshed in the same commit (prompt/schema changed:
  `languages` added).
- Unit tests: entry-key normalisation, report-only fields excluded from
  `overall`, real-dir absent → skipped, thinking helper per model family,
  letter-spaced garble detection.
