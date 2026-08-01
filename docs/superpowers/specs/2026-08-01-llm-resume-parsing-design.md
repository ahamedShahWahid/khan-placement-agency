# LLM resume parsing (roadmap slice 3) — design

Approved by Ahamed 2026-08-01. Implements `docs/mvp-launch-roadmap.md` step 3:
Gemini parser behind the existing `ResumeParser` Protocol, library parser as
fallback, gold-dataset growth, and the Parse-F1 acceptance criterion (≥ 0.90)
measured on the LLM lane.

Decisions made during brainstorming:

- **Two eval lanes.** CI keeps the deterministic library-parser gate (no
  network, floor 0.85). The 0.90 acceptance number is measured on-demand
  against live Gemini and recorded as a committed report. CI never calls
  Gemini.
- **Fall back to library on any LLM failure** — a resume parse never fails
  because Gemini is down. `parser_name` provenance (`llm.gemini.v1` vs
  `library.v1`) makes degradation observable in stored rows.
- **Gold dataset grows 8 → 20** with hard cases.
- Selection mirrors the match-explainer convention: `JOBIFY_RESUME_PARSER` =
  `"llm"` (default) | `"library"`, reusing `JOBIFY_GEMINI_API_KEY`; no key +
  `"llm"` degrades to library with a warning (dev boots keyless).
- Sending resume text to Gemini has precedent — the embedding path already
  does; no new consent surface.

## Module layout (`core/src/jobify/integrations/parser/`)

- **`llm_parser.py` — `GeminiResumeParser`** (implements `ResumeParser`):
  `parse()` = shared `text.extract_text()` (unchanged — PDF/DOCX handling and
  the 64 KB truncation stay in one place) → one Gemini call → pydantic
  validation → `ParsedResume(parser_name="llm.gemini.v1", raw_text=<extracted>)`.
  No top-level `google.genai` import (explainer precedent — the module must
  import cleanly without the SDK). Extraction `ParserError`s (password-protected,
  no-text, unsupported type) propagate untouched — they are permanent
  regardless of parser.
- **`fallback.py` — `FallbackResumeParser(primary, fallback)`**: try primary;
  on ANY exception EXCEPT an extraction-raised `ParserError`, structlog
  `parse.llm-failed` (error class only, never resume text) and run the
  fallback on the same input. Extraction `ParserError`s propagate — falling
  back would just re-fail extraction. Implementation note: the primary
  re-raises extraction errors distinguishably (the `GeminiResumeParser`
  extracts first, so a `ParserError` raised BEFORE the model call is
  extraction's; simplest correct mechanism — `GeminiResumeParser` wraps its
  own post-extraction failures in a dedicated `LlmParserError(ParserError)`
  subclass so the composite can tell the layers apart).
- **Factory `get_resume_parser()` lives in `jobify_worker.runtime`** (the
  explainer precedent exactly — worker owns settings and genai-client
  construction; core modules stay config-free and constructor-injected):
  `"llm"` → `FallbackResumeParser(GeminiResumeParser(client=..., model=...),
  LibraryResumeParser())`; `"library"` → `LibraryResumeParser()`; `"llm"`
  without an API key → warning log + `LibraryResumeParser()` (unlike the
  explainer's raise — the parser has a same-quality-as-today fallback).
  Lazy singleton `_resume_parser` with the same monkeypatch-before-first-call
  contract as `get_match_explainer`.

## Settings (`WorkerSettings`)

- `resume_parser: Literal["library", "llm"] = "llm"` (`JOBIFY_RESUME_PARSER`)
- `resume_parser_model: str = "gemini-2.5-flash"` (`JOBIFY_RESUME_PARSER_MODEL`)
- Reuses existing `gemini_api_key`.

Worker `tasks/parse.py` swaps its hardcoded `LibraryResumeParser()` default
for `get_resume_parser()`; the `parser=` injection parameter for tests stays.

## Gemini call contract

- Model `gemini-2.5-flash`, **`thinking_budget=0`** (pinned lesson: thought
  tokens starve `max_output_tokens`), `temperature=0`,
  `response_mime_type="application/json"`, `response_schema` mirroring
  `ParsedResume` minus `schema_version`/`parser_name`/`raw_text` (ours, not
  the model's), `max_output_tokens=8192` (resume JSON is big — the
  explainer's 200-cap starvation must not recur).
- Input: the extracted text (already ≤ 64 KB). Prompt is extract-only: no
  inference of missing fields, empty list over guessing, dates verbatim as
  written (the schema's date strings are free-form by contract).
- Failure taxonomy inside `GeminiResumeParser`: API error, blocked/empty
  response, JSON failing pydantic validation → raise `LlmParserError` after
  logging the raw model text at debug (diagnosability precedent). ONE
  attempt, no internal retry — the fallback is the recovery; Celery-level
  retry semantics are unchanged.

## Eval — two lanes, one harness

- `jobify.eval.parse_f1.eval_gold_dataset()` gains a parser seam:
  `eval_gold_dataset(data_dir=None, parse_fn=None)` where
  `parse_fn: Callable[[str], ParsedResume]` defaults to the current library
  text-only path. Scoring/normalization untouched.
- **CI lane (unchanged):** `test_library_parser_meets_quality_gate` keeps the
  library parser, per-field floors (email .95 / phone .85 / name .70 /
  skills .75) and overall 0.85. The library parser is the production
  fallback; CI keeps guarding what it ships.
- **LLM lane (on-demand):** a second eval test, skipped unless
  `JOBIFY_GEMINI_API_KEY` is set AND `JOBIFY_PARSE_EVAL_PARSER=llm`; runs the
  same harness through `GeminiResumeParser`'s text path (extraction bypassed,
  same as the library lane) and asserts **overall ≥ 0.90** + the same
  per-field floors. Invocation:
  `JOBIFY_PARSE_EVAL_PARSER=llm uv run pytest -m eval -s`.
- **The acceptance record** is `core/data/parse_eval/LLM_EVAL_REPORT.md` —
  the committed report (date, model, dataset size, per-field + overall F1,
  per-example breakdown) produced by the LLM-lane run. Re-running the lane
  after prompt/model changes refreshes the report in the same commit.

## Gold dataset growth (8 → 20)

Twelve new `.txt` + `.expected.json` pairs (ids 009–020) targeting known
library-parser weaknesses so the lane delta is meaningful: mangled
two-column/table extraction artifacts, career gap + return, non-tech roles
(sales manager, operations executive, teacher), projects-only fresher,
10+ year senior with long history, mixed Hindi-English phrasing,
unconventional section headers ("Where I've Worked"), certifications-heavy
profile, phone-only contact block (no email), name embedded mid-header.

Authoring rule (data-contract lesson): write the `.txt` FIRST, derive
`expected.json` by reading it — never from the persona sketch. If a new
example tanks a *library* floor in CI, review the expectation first, then
either fix it or document the limitation in `000_README.md`. Floors are
never silently lowered.

## Testing (beyond eval)

- **Unit — `GeminiResumeParser`** (faked genai client): happy path (JSON →
  validated `ParsedResume`, provenance + raw_text correct); blocked/empty
  response → `LlmParserError`; invalid JSON → `LlmParserError`; extraction
  `ParserError` propagates WITHOUT a model call.
- **Unit — `FallbackResumeParser`**: primary success (fallback never called);
  primary raises `LlmParserError` → fallback result returned + `parse.llm-failed`
  logged; extraction `ParserError` propagates uncaught.
- **Unit — factory**: selection matrix (llm/library × key/no-key); singleton
  reset follows the existing patched-fixture pattern (patch every importing
  module — the three-module lesson).
- **Integration — worker parse task**: injected fake LLM parser → stored row
  carries `llm.gemini.v1`; injected always-raising primary inside the
  composite → row carries `library.v1` AND `parse_status='parsed'`.
- No new DSR/PII surface: nothing new stored; `parsed_json` already DSR-wired.

## Out of scope

- Re-parsing existing resumes (schema stays v1; no migration).
- Prompt-tuning loops beyond meeting the gate.
- Vendor parsers, per-tenant model config, response caching.
- Ratcheting the CI library gate above 0.85 (the 0.90 criterion lives on the
  LLM lane).

## Batch mode (eval + bulk lanes)

**Decision (user-approved 2026-08-01):** the LLM eval lane, and any future
bulk re-parse job, go through the Gemini **Batch API**
(`GeminiResumeParser.parse_texts_batch`) instead of paced interactive
`generate_content` calls. Two independent wins over the original
"20 calls, 13s-paced, one event loop" lane:

- **50% of interactive `generate_content` pricing** for identical output.
- **A separate quota pool** from interactive `generate_content` — the eval
  lane no longer competes with (or gets capped by) whatever RPM/RPD budget
  the free-tier key has already burned on interactive traffic. The original
  lane's 13s pacing and same-event-loop plumbing existed solely to survive
  the interactive free-tier RPM/RPD caps; batch mode needs neither, so both
  are deleted along with the per-call machinery.

**The LIVE path (`parse`/`parse_text`) stays interactive — never moved to
batch.** Batch jobs are asynchronous and can take anywhere from minutes to
hours to complete; the **≤10-min first-match criterion in
`IMPLEMENTATION_SPEC.md`** depends on the live parse path returning within
one interactive round trip per resume upload. `parse_texts_batch` is
therefore a separate, deliberately
sync method (batch create+poll is long-running job management, not
request/response) used only by the eval lane today and reserved for a future
bulk re-parse job — never called from the worker's parse task.

Contract: one batch job of inlined requests (same system instruction,
response schema, and generation config as `parse_text` — factored into
`_generate_content_config()`), polled to a terminal state, all-or-nothing —
a job-level failure/timeout or ANY per-item failure (missing/error response,
schema-invalid JSON) raises `LlmParserError` naming the failing indices
rather than returning a partial list. Response-to-request correlation relies
on the SDK's documented order guarantee for inlined batch responses
(`google.genai.types.BatchJobDestination.inlined_responses`: "will be in the
same order as the input requests") rather than any per-item metadata
round-trip.
