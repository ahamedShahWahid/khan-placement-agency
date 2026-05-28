# LLM Match Explanations (sub-project G) — Design

**Date:** 2026-05-28
**Status:** Approved (design)
**Owner area:** `api/` (backend only)

## Goal

Add a Gemini-backed match-explanation generator behind a `MatchExplainer`
interface, selectable by env var, leaving the score-worker logic and the
`matches.explanation` JSONB shape unchanged. Ships dark (default `templated`);
flipping to Gemini is a one-line env change.

BRD §14 #1. The codebase's existing notes (CLAUDE.md "Match explanations") already
pre-committed this shape: "a `MatchExplainer` Protocol with `templated` and `llm`
impls will route via an env var; the score worker call site doesn't change."

## Background — verified current state

- `kpa/scoring/explain.py` — `templated_explanation(*, components, vector,
  structured, total, threshold, job_title, job_locations, job_min_exp_years,
  job_max_exp_years, job_ctc_max, employer_name, applicant_expected_ctc,
  applicant_locations) -> dict[str, str]`. Pure, deterministic. Returns
  `{fit, caveat, generator="templated", generator_version="1"}`. Has unit tests
  in `tests/unit/test_explain_templated.py`.
- `kpa/workers/tasks/score_applicant.py` and `score_job.py` each call
  `templated_explanation(...)` once per match in a plain `for` loop inside the
  `async def` compute phase (between Txn 1 load and Txn 2 UPSERT). Both do a
  **local** `from kpa.scoring.explain import templated_explanation` inside the
  function body. `ms.crosses_threshold` / `ms.total >= threshold` is available
  per match.
- `matches.explanation` is `Mapped[dict[str, str] | None]` JSONB, nullable.
  UPSERT writes/updates it on every (re)score.
- Provider patterns to mirror: `GeminiEmbeddingProvider`
  (`kpa/integrations/embeddings/gemini.py`) wraps `google.genai` and maps
  `errors.ServerError`/`ClientError(429)` → transient, others → permanent; the
  lazy-singleton factories `get_embedding_provider()` / `get_email_channel()` in
  `kpa/workers/celery_app.py` build the impl on first call from `settings`.
- Settings pattern: `KPA_MATCH_SURFACE_THRESHOLD` etc. declared as `Field(...,
  alias="KPA_...")` with a `@field_validator` for enum-like strings (see
  `email_channel`).
- `google-genai>=1.0,<2` is already a dependency (embeddings). No text-generation
  usage exists yet.

## Decisions (confirmed with owner)

1. **LLM scope = surfaced matches only.** Gemini is called only for matches at/
   above `match_surface_threshold` (the ones users see in the feed). Below-
   threshold matches keep the free templated text. The gate lives *inside* the
   Gemini explainer, so the worker call site is identical for both impls.
2. **Failure = fall back to templated.** Any Gemini failure (genai
   `ServerError`/`ClientError`/`APIError`, timeout, JSON parse failure, schema
   mismatch) logs `explain.llm-failed` (warning, `exc_info=True`) and returns the
   templated explanation. `explain()` **never raises** — scoring is never failed
   or retried by the explainer.

## Architecture

```
kpa/scoring/explain.py        templated_explanation(...)   — UNCHANGED; the fallback
kpa/scoring/explainer.py      ExplainContext (frozen dataclass: the 13 score-context fields)
                              MatchExplainer (Protocol): async explain(ctx) -> dict[str,str]
                              TemplatedExplainer        — wraps templated_explanation()
                              _templated_from_ctx(ctx)  — shared ctx->templated helper
kpa/scoring/llm_explainer.py  GeminiMatchExplainer       — google.genai text gen; own module
                                                           so importing `explainer` never pulls
                                                           in genai (mirrors embeddings __init__)
celery_app.py                 get_match_explainer()      — lazy singleton, reads settings
score_applicant.py/score_job.py  build ExplainContext, await get_match_explainer().explain(ctx)
```

### `ExplainContext` (frozen dataclass)
Exactly the 13 keyword fields `templated_explanation` accepts:
`components: dict[str, float]`, `vector: float`, `structured: float`,
`total: float`, `threshold: float`, `job_title: str`,
`job_locations: list[str]`, `job_min_exp_years: int`, `job_max_exp_years: int`,
`job_ctc_max: Decimal | None`, `employer_name: str`,
`applicant_expected_ctc: Decimal | None`, `applicant_locations: list[str]`.

### `MatchExplainer` Protocol
`async def explain(self, ctx: ExplainContext) -> dict[str, str]` returning the
same 4-key shape (`fit`, `caveat`, `generator`, `generator_version`).

### `TemplatedExplainer`
`async def explain(ctx)` → `_templated_from_ctx(ctx)` (calls
`templated_explanation` with ctx fields). Always sync work under the hood; the
`async` is for interface uniformity.

### `GeminiMatchExplainer(*, client, model)`
- Constructor takes an **injectable** `google.genai` client (so unit tests pass a
  fake — cleaner than the embeddings provider, which builds its client
  internally). `model: str`.
- `async def explain(ctx)`:
  1. **Surfaced gate:** `if ctx.total < ctx.threshold: return _templated_from_ctx(ctx)`
     — no Gemini call.
  2. Build a compact prompt from ctx (scores, job title/employer, locations, exp
     band, ctc) + a system instruction asking for a one-sentence `fit` and an
     optional one-sentence `caveat`, ≤25 words each, concrete, no fluff.
  3. `await client.aio.models.generate_content(model=self._model, contents=prompt,
     config=types.GenerateContentConfig(system_instruction=..., response_mime_type=
     "application/json", response_schema=<OBJECT{fit:STRING, caveat:STRING}>,
     temperature=0.3, max_output_tokens=200))`.
  4. Parse `resp.text` as JSON → `{"fit": str, "caveat": str}` (caveat optional →
     `""`). Return `{fit, caveat, generator="llm", generator_version=LLM_GENERATOR_VERSION}`.
  5. **`except Exception`** (broad, on purpose): `_log.warning("explain.llm-failed",
     exc_info=True)` and `return _templated_from_ctx(ctx)`. Never raises.
- Constants: `LLM_GENERATOR = "llm"`, `LLM_GENERATOR_VERSION = "1"`.
- The exact `google-genai` 1.x structured-output API (`GenerateContentConfig`,
  `response_schema` form) must be confirmed against context7 during
  implementation, since this is the first text-gen call in the repo.

### `get_match_explainer()` factory (`celery_app.py`)
Lazy singleton `_match_explainer`, mirroring `get_embedding_provider` /
`get_email_channel`:
- `settings.match_explainer == "templated"` → `TemplatedExplainer()`.
- `== "llm"` → `GeminiMatchExplainer(client=genai.Client(
  api_key=settings.gemini_api_key.get_secret_value()),
  model=settings.match_explainer_model)` (lazy `from google import genai` inside
  the branch so genai isn't imported in the templated path).
- else → `ValueError`.

### Worker wiring (both score workers)
Replace the local `from kpa.scoring.explain import templated_explanation` +
inline `templated_explanation(...)` with:
```python
from kpa.scoring.explainer import ExplainContext
from kpa.workers.celery_app import get_match_explainer
...
ctx = ExplainContext(components=ms.components, vector=ms.vector, structured=ms.structured,
                     total=ms.total, threshold=_settings.match_surface_threshold,
                     job_title=job_title, job_locations=job_locs,
                     job_min_exp_years=job_min_exp, job_max_exp_years=job_max_exp,
                     job_ctc_max=job_ctc_max, employer_name=<employer_name|job_employer_name>,
                     applicant_expected_ctc=applicant_ctc, applicant_locations=applicant_locs)
explanation = await get_match_explainer().explain(ctx)
```
The compute loop is already inside `async def`, so `await` is fine. Keep the
import **local** (inside the function body) so the integration fixture only needs
to patch `celery_app.get_match_explainer` + seed the `_match_explainer` cache.

### Config
- `match_explainer: str = Field(default="templated", alias="KPA_MATCH_EXPLAINER")`
  with `@field_validator` enforcing `{"templated", "llm"}`.
- `match_explainer_model: str = Field(default="gemini-2.5-flash",
  alias="KPA_MATCH_EXPLAINER_MODEL")`.

### No migration
`matches.explanation` JSONB already exists with this shape; the LLM path only
changes the `generator`/`generator_version` values.

## Testing

### Unit
- `tests/unit/test_explainer.py`: `TemplatedExplainer.explain(ctx)` returns the
  same dict as `templated_explanation(**fields)`; `generator == "templated"`.
- `tests/unit/test_llm_explainer.py` with a **fake genai client**
  (`client.aio.models.generate_content` async, returns object with `.text`):
  - surfaced ctx (total ≥ threshold) → client called once, JSON parsed,
    `{fit, caveat, generator="llm"}`.
  - non-surfaced ctx (total < threshold) → client **not** called, templated
    returned (`generator == "templated"`).
  - client raises → templated fallback, no exception, `generator == "templated"`.
  - client returns invalid/empty JSON → templated fallback, no exception.
- `tests/unit/test_settings.py`: `match_explainer` default `"templated"`; `"llm"`
  accepted; invalid value raises `ValidationError`; `match_explainer_model`
  default present.

### Integration (real Postgres)
- `patched_match_explainer` fixture in `tests/integration/conftest.py` (mirrors
  `patched_embedding_provider`): a fake explainer returning a marker
  (`generator="fake-llm"`); patches `celery_app.get_match_explainer` and seeds the
  `_match_explainer` cache.
- `tests/integration/test_llm_explainer_wiring.py`: with the fake explainer
  injected, run a score (applicant or job) that produces a surfaced match; assert
  the stored `matches.explanation["generator"] == "fake-llm"`. Existing score
  integration tests continue to pass unchanged because the default
  (`templated`) produces identical output to before.

## Out of scope
Streaming, per-rule LLM weighting, prompt A/B, caching by components-hash
(the declined "regenerate-gated" option), and any frontend change (the app
already renders `explanation.fit`/`.caveat` and tolerates null).

## Risks / follow-ups
- **First text-gen call in the repo** — the google-genai structured-output API
  must be verified against context7; a malformed config would silently always
  fall back to templated (behind an off-by-default flag, so low blast radius).
- **Cost** — surfaced-only bounds calls to visible matches; regenerate-on-rescore
  still re-calls Gemini each rescore. Components-hash caching is a noted follow-up.
- **No `task_type`/title nuance** — unlike embeddings, text gen is a single
  prompt; nothing provider-specific leaks to the worker.
