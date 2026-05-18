# Resume parse worker (Celery + library/regex parser) — design

**Date:** 2026-05-18
**Spec ref:** `IMPLEMENTATION_SPEC.md` §6.1 (resume parse + embed), §7 (AI/ML strategy — `ResumeParser` is the seam), §8 (background jobs / Celery), §9.3 (file uploads), §11.1 (MVP runtime — this plan introduces Redis), §13 (P1 sequencing — Celery moves up from P3).
**Status:** Approved by Ahamed. Ready for implementation plan.

This is the first asynchronous-worker slice. It introduces Celery + Redis to the stack (one step earlier than §13's "P3 — Notifications" placement) and ships a deterministic library/regex resume parser behind a Protocol that an LLM-backed impl will later swap into.

## Why this slice

The resume upload route (P1.0) drops files into storage and creates rows with `parse_status=pending`. Nothing transitions them out of `pending` today — a resume is just bytes on disk. This plan turns that pipeline live end-to-end:

1. Upload commits → worker dispatched.
2. Worker extracts text, populates a structured `parsed_json`, transitions to `parsed`.
3. Client polls the existing `GET /v1/applicants/{aid}/resumes/{rid}` and sees the transition.

After this plan:
- The matcher (later plan) has structured candidate data to score against jobs.
- The embedding worker (later plan) has canonical text to embed.
- The whole async-worker pattern (Celery task + retry + idempotency + observability) is reusable for every subsequent worker the spec lists (`embed`, `score`, `notify`, `dsr`).

## Spec deltas this lands

When the plan ships:

- **§13** — P1 introduces Redis + Celery (the spec currently says P3).
- **§11.1** — same edit — Redis is no longer "deferred to P3".
- **§6.1** — this plan implements step 3a only (parse + persist `parsed_json` + set status). Step 3b (embedding) and step 3c (initial match dispatch) remain as future plans.

## Scope decisions resolved during brainstorming

| # | Decision | Resolution |
|---|---|---|
| 1 | Worker infrastructure | Celery + Redis now (advances spec §13 from P3). Local Redis via Homebrew (`brew install redis`). |
| 2 | Parser strategy | Library/regex now. `ResumeParser` Protocol; concrete `LibraryResumeParser`. LLM impl swaps in later behind the same Protocol once §14 #1 (LLM provider) is resolved. |
| 3 | Parser scope | Full §6.1 schema: name, contacts, skills, experience[], education[], certifications[]. Best-effort regex/keyword extraction; empty arrays where regex can't find anything. |
| 4 | Retry policy | Tenacity-style: 3 attempts, exponential backoff with jitter, then `failed` + `parse_error`. Permanent failures (`ParserError`) skip retry. |
| 5 | Status surfacing | Polling the existing `GET /v1/applicants/{aid}/resumes/{rid}`. No new endpoint, no new columns. FCM push deferred to the P3 notifications plan. |

## Architecture overview

```
[Client] → POST /v1/applicants/{aid}/resumes → uvicorn (API process)
                                                       ↓
                                          writes file to LocalFileStorage
                                          inserts resume row (status=pending)
                                          await session.commit()
                                          parse_resume.delay(str(resume.id))   ←─┐
                                          returns 201                            │
                                                                                 │ Redis broker
                                                                                 │
[Worker: `uv run celery -A kpa.workers.celery_app worker --pool=solo -Q parse`] ─┘
                                                       ↓
                                          loads resume row → idempotency gate
                                          marks status=parsing → commit
                                          reads bytes from LocalFileStorage
                                          extract_text() → LibraryResumeParser.parse()
                                          writes parsed_json + status=parsed → commit
```

**Three new packages and one infra dep:**

```
api/src/kpa/
  workers/                       NEW
    __init__.py
    celery_app.py                Celery instance, broker config, per-worker engine init
    tasks/
      __init__.py
      parse.py                   parse_resume sync task wrapping async body

  integrations/parser/           NEW
    __init__.py
    base.py                      ResumeParser Protocol + ParsedResume + errors
    text.py                      PDF/DOCX text extraction (pypdf → pdfminer fallback)
    library.py                   LibraryResumeParser — regex + keyword impl
    skills_dict.py               Curated ~200-entry skill keyword list

  routes/resumes.py              MODIFY — dispatch parse_resume.delay() after commit
  settings.py                    APPEND — KPA_REDIS_URL, KPA_CELERY_TASK_ALWAYS_EAGER
```

**Runtime topology:** Two processes locally — uvicorn (API) and `celery worker` (parse). They communicate via Redis. Postgres is shared. The same `LocalFileStorage` root (`KPA_STORAGE_ROOT=var/uploads`) is mounted by both processes; uvicorn writes, worker reads.

**No new tables, no migration.** The plan reuses `kpa.resumes`'s existing `parse_status`, `parse_error`, `parsed_json`, `updated_at` columns.

## Parser interface + parsed_json schema

`integrations/parser/base.py` owns the contract:

```python
class ExperienceEntry(BaseModel):
    company: str | None = None
    title: str | None = None
    start: str | None = None      # "Jan 2020" / "2020" / null — free-form for now
    end: str | None = None        # "Present" / "Dec 2022" / null
    summary: str | None = None

class EducationEntry(BaseModel):
    institution: str | None = None
    degree: str | None = None     # "B.Tech", "M.Sc", "MBA"
    field: str | None = None
    end_year: int | None = None

class CertificationEntry(BaseModel):
    name: str | None = None
    issuer: str | None = None
    year: int | None = None

class ParsedResume(BaseModel):
    """Canonical parsed-resume payload. Stored verbatim in resumes.parsed_json."""
    model_config = ConfigDict(frozen=True)

    schema_version: int = 1                  # bump on any schema change
    parser_name: str                         # provenance: "library.v1" / "llm.anthropic.v1"
    raw_text: str                            # full extracted text, truncated to 64 KB

    name: str | None = None
    email: str | None = None
    phone: str | None = None

    skills: list[str] = []                   # lowercased, deduped, sorted
    experience: list[ExperienceEntry] = []
    education: list[EducationEntry] = []
    certifications: list[CertificationEntry] = []


class ResumeParser(Protocol):
    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume: ...


class ParserError(Exception):
    """Permanent failure — no retry. Bad input.

    Examples: password-protected PDF, image-only PDF (no text extractable),
    unsupported MIME type, `.doc` legacy binary format (deferred).
    """

class TransientParserError(Exception):
    """Recoverable failure — Celery autoretry up to 3 times with backoff.

    Examples: storage I/O hiccup, unexpected library exceptions worth retrying.
    """
```

**Why `parser_name` is a field:** future consumers (admin tooling, analytics, re-parse migrations) need to know which parser produced any given row's `parsed_json`. Without this provenance marker, a v2 parser rollout couldn't distinguish "this row was parsed by the old library impl" from "this row was parsed by the new LLM impl" except by timestamp guesswork.

**Why permanent/transient errors are separate classes:** `autoretry_for=(TransientParserError,)` in the Celery task lets corrupt-PDF failures terminate on attempt 1 while storage hiccups get up to 3 attempts. A `transient: bool` attribute on a single exception class would work too but loses the type-system signal at the catch site.

## Library parser impl

`LibraryResumeParser.parse_name` = `"library.v1"`. Best-effort across all schema fields:

| Field | Approach |
|---|---|
| `raw_text` | Output of `extract_text()`, truncated to 64 KB |
| `name` | Heuristic: first non-empty line with capitalised words, ≤5 tokens, no digits/`@` |
| `email` | Standard email regex; first match wins |
| `phone` | Tolerant Indian + intl regex (`+91-`, `+91 `, 10-digit, E.164); first match wins |
| `skills` | Case-insensitive keyword match against `skills_dict.py` (~200 entries); deduped + sorted |
| `experience` | Regex for `<Month>? <Year>` ↔ `<Month>? <Year>\|Present` ranges; surrounding ±50 chars become `summary`; `company`/`title` left null (need LLM) |
| `education` | Regex finds degree keywords (`B\.?Tech\|B\.?E\|B\.?Sc\|M\.?Tech\|M\.?Sc\|MBA\|PhD`) + optional 4-digit year; `institution`/`field` best-effort capture |
| `certifications` | Lines containing `Certified\|Certification`; captures following word + optional year |

The regex impl will score far below the BRD's parse F1 ≥ 0.90 target (spec §7) — that gate applies to the LLM impl. This plan's success criterion is "the pipeline works end-to-end", not "parser is good".

`skills_dict.py` ships with curated coverage of languages (Python, Java, Go, …), frameworks (FastAPI, React, Spring, …), data (Postgres, Redis, Kafka, …), cloud (AWS, GCP, Azure, …), and tooling (Docker, K8s, Terraform, …). Deliberately not exhaustive.

## Text extraction

`integrations/parser/text.py` is pure-function:

```python
async def extract_text(*, content: bytes, content_type: str) -> str:
    """Extract plain text from a resume blob. Truncated to 64 KB.

    Raises ParserError on unsupported types, password-protected files,
    or empty extraction.
    Raises TransientParserError on unexpected library exceptions worth retrying.
    """
```

Implementation:
- **`application/pdf`**: try `pypdf` first (fast, handles most modern PDFs). If extracted text is empty/garbled (heuristic: length < 50 chars), fall back to `pdfminer.six` (more layout-tolerant, slower). If both fail → `ParserError("no_text_extracted")`.
- **`application/vnd.openxmlformats-officedocument.wordprocessingml.document` (`.docx`)**: `python-docx`. Read paragraphs and table cells, join with `\n`.
- **`application/msword` (`.doc` legacy)**: explicitly raise `ParserError("doc_legacy_not_supported")`. The upload route's content-type whitelist accepts `.doc`, but parsing legacy binary Word requires antiword/LibreOffice (binary deps) — deferred. The user gets a clear `failed` state on `.doc` uploads until that lands.
- Any other content-type → `ParserError("unsupported_content_type")`.
- Password-protected PDFs detected via `pypdf` raising → caught and re-raised as `ParserError("password_protected")`.

## Worker mechanics

### Celery setup (`workers/celery_app.py`)

```python
celery_app = Celery(
    "kpa",
    broker=settings.redis_url,
    backend=settings.redis_url,                  # result backend; result_expires=3600
    include=["kpa.workers.tasks.parse"],
)
celery_app.conf.update(
    task_default_queue="parse",                  # all tasks route here for MVP
    task_acks_late=True,                         # ack only after task body returns
    worker_prefetch_multiplier=1,                # one task in flight per worker
    task_always_eager=settings.celery_task_always_eager,
    task_eager_propagates=True,
    broker_connection_retry_on_startup=True,
    result_expires=3600,
)
```

Per-worker-process engine + sessionmaker built at the `worker_process_init` signal; disposed at `worker_shutting_down`. A `get_session_maker()` helper falls back to building one on demand for tests in eager mode (no signal fires).

### Task body (`workers/tasks/parse.py`)

```python
@celery_app.task(
    name="kpa.parse_resume",
    bind=True,
    max_retries=3,
    autoretry_for=(TransientParserError,),
    retry_backoff=2,                             # 2s → 4s → 8s, jittered, capped 60s
    retry_backoff_max=60,
    retry_jitter=True,
    acks_late=True,
)
def parse_resume(self, resume_id_str: str) -> None:
    asyncio.run(_parse_resume_async(UUID(resume_id_str)))
```

The sync entry point exists because Celery tasks are sync by default. `asyncio.run()` is the simplest async-bridging pattern; combined with `--pool=solo` (single concurrency) it avoids the per-event-loop complications of prefork. P5 hardening can swap to prefork + per-process engine without changing the task body.

### Three-transaction split

The async body splits work into three transactions deliberately:

1. **Load + gate** (`async with sm() as session`): fetch row, check idempotency, mark `parsing`, commit. Cheap, holds no row lock during the slow part.
2. **Extract + parse** (no DB): `storage.read()` → `extract_text()` → `parser.parse()`. Can take seconds. No row lock held.
3. **Persist** (`async with sm() as session`): re-fetch row, verify it's still `parsing` (refuses to overwrite if status mutated externally), write `parsed_json` + status, commit.

This pattern prevents the (multi-second) parse from holding a row lock and lets polling clients see the `parsing` transition immediately.

### Idempotency

Three guards against double-processing:

- **Entry gate**: skip if `parse_status ∈ {parsed, failed, parsing}`. A retried or duplicate task on a terminal row is a no-op.
- **Pre-persist check**: re-fetch row inside the final transaction; refuse if status isn't `parsing` (admin reset, manual mutation).
- **Per-error policy**: `ParserError` marks `failed` immediately. `TransientParserError` triggers Celery autoretry (up to 3). Any other unexpected exception is wrapped to trigger retry, and on retries exhausted marks `failed` with `parse_error="unexpected: <ExceptionClass>"`.

### Dispatch from upload route

`routes/resumes.py` POST handler, one block added after the existing `session.commit()`:

```python
from kpa.workers.tasks.parse import parse_resume

try:
    parse_resume.delay(str(resume.id))
except Exception as exc:                         # Redis down, broker unreachable, etc.
    _log.warning("dispatch.broker-unavailable",
                 resume_id=str(resume.id),
                 error=type(exc).__name__)
    # Upload promise is durable — the row exists. Admin tooling can replay.
```

The dispatch happens **after** the commit, so a rolled-back upload never enqueues a phantom task. Broker failures are logged but **don't** fail the upload — the row sits at `pending` until an admin re-dispatches (admin tooling lands later).

## Settings + env

| Variable | Required | Default | Purpose |
|---|---|---|---|
| `KPA_REDIS_URL` | yes | — | Redis connection string. Validator requires `redis://` or `rediss://`. |
| `KPA_CELERY_TASK_ALWAYS_EAGER` | no | `false` | When `true`, `.delay()` runs the task body inline in the caller. Used by tests; never set in production. |

`.env.example` gets both lines under a `# Background workers (Celery + Redis)` comment header.

## New dependencies

- `celery[redis]>=5.5,<6` — bundles `redis-py`.
- `pypdf>=5,<6` — primary PDF text extractor.
- `pdfminer.six>=20240706` — fallback PDF extractor for layout-heavy / Word-exported PDFs.
- `python-docx>=1.1,<2` — DOCX text extractor.

## Testing strategy

### Unit (no DB, no Redis)

- `test_parser_text.py`: pypdf happy path, pdfminer fallback fires when pypdf returns empty, DOCX extraction, password-protected PDF → `ParserError`, image-only PDF → `ParserError("no_text_extracted")`, `.doc` → `ParserError("doc_legacy_not_supported")`, unsupported MIME → `ParserError`.
- `test_parser_library.py`: canned text in → expected `ParsedResume` out. Covers email regex, phone regex (Indian + intl), skills keyword dictionary, experience date-range regex, education degree regex, name heuristic, empty resume → valid `ParsedResume` with empty arrays.
- `test_parse_task.py`: direct call to `_parse_resume_async` with mocked storage + session. Asserts happy path persists `parsed_json` + status=parsed; `ParserError` → status=failed (no retry); `TransientParserError` reraises (for Celery to catch); idempotency on terminal-state rows is a no-op.

### Integration (real Postgres, Celery in eager mode)

- `test_parse_pipeline.py`: monkeypatch `KPA_CELERY_TASK_ALWAYS_EAGER=true`, POST a tiny real PDF, GET the resume and assert eventual `parse_status=parsed` with non-null `parsed_json` containing schema_version=1, parser_name="library.v1", and the expected email/phone/skills from the fixture.
- `test_parse_pipeline_failure.py`: POST a malformed PDF, assert eventual `parse_status=failed` with non-null `parse_error`.
- `test_dispatch_resilient_to_redis_down.py`: disable eager mode, point `KPA_REDIS_URL` at an unreachable port, POST upload, assert 201 still returns and row stays `pending`. Guards the "upload promise survives broker outage" invariant.

### Fixtures

Tiny (<5 KB each) sample resumes in `tests/fixtures/resumes/`:
- `tiny.pdf` — one paragraph + email + phone + a handful of skill keywords
- `tiny.docx` — same shape
- `password_protected.pdf` — guarded against accidental read
- `image_only.pdf` — scanned page with no extractable text
- `malformed.pdf` — header bytes but corrupt body

### Eager-mode caveat

Setting `task_always_eager=True` runs the task body inline — bypasses the broker, the worker process, and the prefork pool. It exercises the real task body, parser, storage, and DB writes but does not catch broker-side issues (queue routing, serialization, retry mechanics). Those are covered by direct calls in `test_parse_task.py`.

### Test count

~12 unit + ~3 integration = **~15 new tests**. Combined with post-merge baseline of 103 → ~118 total.

## Security posture

- Redis: 127.0.0.1-bound in local dev (Homebrew default). Prod uses ElastiCache with TLS + AUTH (§11.2); the settings field accepts `rediss://` for that swap.
- Worker process inherits the API's DB credentials — no new attack surface.
- Parser is pure-Python; no shelling out to LibreOffice/antiword (those are deferred).
- `parse_error` capped at 1000 chars to prevent malicious resumes producing oversized error rows.
- `raw_text` truncated to 64 KB to prevent oversized `parsed_json` rows.
- No tokens, IDs, or file bytes are logged. Worker log lines carry only `resume_id`, `parser_name`, `skills_count`, error class names.

## Observability

- structlog config already covers the worker process (same key=value output). No new config needed.
- New log events follow the existing `<domain>.<event>` convention: `parse.row-missing`, `parse.skip-already-final`, `parse.skip-in-progress`, `parse.row-mutated-mid-parse`, `parse.unexpected`, `parse.failed`, `parse.complete`, `dispatch.broker-unavailable`.
- Celery's own stdout logging is left as-is (not piped through structlog) — wiring that is a P3 hardening item.

## Out of scope (intentionally — handled by later plans)

- **Embedding worker** — blocked on §14 #2 (embedding provider + dimension).
- **Match-trigger worker** — blocked on jobs schema.
- **LLM-backed `ResumeParser` impl** — interface ships here; impl deferred behind §14 #1 (LLM provider) and §9.2 (DPDP residency).
- **`.doc` legacy binary parsing** — raises `ParserError("doc_legacy_not_supported")` until antiword/LibreOffice deps land.
- **OCR for image-only PDFs** — raises `ParserError("no_text_extracted")` for now.
- **Magic-byte content-type verification + ClamAV** — already noted as out of scope by the P1.0 plan; still deferred.
- **Admin "replay failed parse" tooling** — `failed` rows accumulate until P4-era admin tooling.
- **Status push notifications (FCM)** — polling only. §6.1 step 4's push lands with the P3 notifications plan.
- **Parse F1 gold-dataset CI gate** — BRD ≥ 0.90 target (spec §7) applies to LLM parser. Library parser's score is informational only.
- **`/v1/applicants/me/resumes` alias** — independent small follow-up (deferred from both the P1.0 plan and the auth plan).
- **Schema-version migration tooling** — `parsed_json.schema_version=1`. A v2 bump owns its own re-parse plan.
- **Celery `--pool=prefork` + per-process engine tuning** — P5 hardening; the code already supports it via the `worker_process_init` signal.
- **`/health`/`/ready` for the worker process** — a P3 observability item.
