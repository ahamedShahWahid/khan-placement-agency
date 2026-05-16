# Resume upload skeleton — design

**Date:** 2026-05-16
**Spec ref:** `IMPLEMENTATION_SPEC.md` §5 (resumes table), §6.1 (resume parse + embed), §9.3 (file uploads), §10 (endpoint surface), §11.1 (local-first storage).
**Status:** Approved by Ahamed. Ready for implementation plan.

This is the first slice of P1 from the spec build sequence. It lands the data plane for resume uploads — the table, the route surface, and a storage interface — without any of the parse/embed/match pipeline. Parsing, Celery, S3, and `/me`-style auth aliases each get their own plan.

## Why a skeleton first

The full resume → parse → embed → match pipeline is a multi-week slice. Breaking it apart so the first PR ships a working **upload + retrieve** endpoint has three benefits:

1. The interface (table schema, route URLs, Storage protocol) becomes concrete before we touch parsing — much easier to discuss "is this the right shape?" against running code than against a doc.
2. Future plans (parse worker, embedding, S3 swap) drop into a stable surface. The route never has to change.
3. We can hand-test end-to-end with `curl` + a real PDF before introducing Celery / external workers.

## Surface

Two endpoints, both nested under the applicant id:

```
POST   /v1/applicants/{applicant_id}/resumes
GET    /v1/applicants/{applicant_id}/resumes/{resume_id}
```

**POST** accepts `multipart/form-data` with one field, `file`. It validates the content-type against a whitelist, checks the size against a configurable cap, persists the bytes through the Storage protocol, and creates a row in `kpa.resumes` with `parse_status = pending`. Returns 201 with the resume metadata.

**GET** returns the resume row (metadata only, no bytes). 404 if the resume doesn't exist, or if it exists but belongs to a different applicant.

Both endpoints 404 when the applicant doesn't exist. There is no `/v1/applicants/me/resumes` alias in this slice — that wires `current_user.applicant_id` into the path and lands when auth ships.

### Error model

All errors flow through the existing RFC 7807 problem+json handler (`api/src/kpa/middleware/error_handler.py`):

| Status | Trigger |
|---|---|
| 404 | Applicant doesn't exist; resume doesn't exist; resume belongs to a different applicant |
| 413 | Uploaded file exceeds `KPA_MAX_UPLOAD_BYTES` (default 10 MB) |
| 415 | Content-type not in `KPA_ALLOWED_RESUME_CONTENT_TYPES` (default: PDF, DOC, DOCX) |
| 500 | Storage write failure (rare; surfaced with request_id) |

## Data model

New table `kpa.resumes`:

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK, default uuid4 | Python-level default via the existing `UuidPK` alias |
| `applicant_id` | UUID, FK → `kpa.applicants.id` ON DELETE CASCADE, nullable=False | parallels the existing applicants → users CASCADE |
| `storage_key` | `String(512)`, nullable=False | opaque to the API — whatever the Storage impl uses. For `LocalFileStorage` it's `resumes/{id}{ext}`, where `ext` is derived from `content_type` via a small whitelist map (`application/pdf → .pdf`, `application/msword → .doc`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document → .docx`). The original filename's extension is *not* trusted. Renamed from spec §5's `s3_key` because we're storage-agnostic. |
| `original_filename` | `String(255)`, nullable=False | preserved for display + future "download original" endpoint |
| `content_type` | `String(127)`, nullable=False | whitelisted at upload time |
| `size_bytes` | `Integer`, nullable=False | 10 MB cap fits in int4 |
| `parse_status` | enum `kpa.resume_parse_status` (`pending`, `parsing`, `parsed`, `failed`), nullable=False, default `pending` | every row in this slice is `pending`; other values defined now to avoid an `ALTER TYPE` migration later |
| `parsed_json` | `JSONB`, nullable | populated by the future parse worker |
| `parse_error` | `Text`, nullable | populated when `parse_status = failed` |
| `created_at` / `updated_at` / `deleted_at` | common aliases | soft delete via `deleted_at` consistent with users + applicants |

**Indexes:** none in this slice beyond the PK + FK. A `(applicant_id, created_at DESC) WHERE deleted_at IS NULL` partial index lands the day we add a "list this applicant's resumes" endpoint.

**Migration:** `api/src/kpa/db/migrations/versions/0002_resumes.py`, hand-written following the pattern of `0001`. Up creates the enum + table; down drops both. Schema persists across downgrade (same reasoning as `0001` — dropping it would destroy `alembic_version`).

## Storage interface

New package `api/src/kpa/integrations/storage/`:

```python
# base.py
from typing import Protocol

class Storage(Protocol):
    async def save(self, *, key: str, content: bytes, content_type: str) -> None: ...
    async def read(self, key: str) -> bytes: ...
    async def delete(self, key: str) -> None: ...
```

```python
# local.py
class LocalFileStorage:
    """Filesystem-backed Storage. Writes under a configurable root.

    Used until S3 lands. The key is treated as a relative path under root,
    with directory creation handled automatically on save.
    """
    def __init__(self, root: pathlib.Path) -> None: ...
    # implements Storage
```

**Wiring:** `app_factory.py` constructs the storage instance from settings and attaches it to `app.state.storage`. Routes read it via `request.app.state.storage` — the same pattern as `db_sessionmaker`.

**Migration to S3 later** is a config + impl change only: add `S3Storage` (boto3), add `KPA_STORAGE_BACKEND` setting, branch in `app_factory.py`. No route or DB change.

### Content as bytes, not streams

For a 10 MB cap, holding the file in memory during the request is fine. FastAPI's `UploadFile` is backed by a `SpooledTemporaryFile`, so up to ~1 MB is in memory and the rest spills to disk anyway. Reading into bytes once is simpler than threading a stream through the Storage protocol; if we ever lift the cap to hundreds of megabytes, the Storage interface becomes stream-based as part of that change.

### Storage root

New setting `KPA_STORAGE_ROOT` (type `pathlib.Path`), default `./var/uploads`, resolved relative to the API's CWD (which the README documents as `api/`). The `var/` directory is gitignored. CI runs use a `tmp_path` fixture instead of touching `var/`.

## Validation

**Content type whitelist** lives in settings as `KPA_ALLOWED_RESUME_CONTENT_TYPES`, default:

- `application/pdf`
- `application/msword`
- `application/vnd.openxmlformats-officedocument.wordprocessingml.document`

The check is on the value the client sends in the multipart part's `Content-Type` header. **This is spoofable** — a malicious client could lie about content-type. Per spec §9.3 the production-grade check is magic-byte verification + ClamAV scanning; both are explicitly deferred until the parse pipeline lands (parsing reads the bytes anyway, so magic-byte detection there is cheap).

**Size cap** from settings: `KPA_MAX_UPLOAD_BYTES`, default `10 * 1024 * 1024` (10 MB), matching spec §9.3. FastAPI's `UploadFile.size` is checked after the body is read; we additionally pass `max_size` to the multipart parser so oversized requests fail fast at the parsing layer where supported.

## Auth bypass

There is no auth in this slice. The applicant id is supplied directly in the URL path as `{applicant_id}` and matched against existing **live** rows in `kpa.applicants` — i.e., rows with `deleted_at IS NULL`. A 404 is returned when no such row exists, whether because the id was never assigned or because the applicant was soft-deleted. Cascading checks against the parent user's `deleted_at` are out of scope here; they land with the DSR plan.

When auth lands (Google OAuth per the user's pick on 2026-05-16):

- A new `/v1/applicants/me/resumes` route resolves `current_user.applicant_id` from the JWT and forwards to the same handler.
- The path-param route can be locked down to admin scope at that point, or removed entirely.

The choice of explicit path param over magic-header bypass keeps the URL evolution clean: `/applicants/{aid}/resumes` is a legitimate admin-scope route forever; `/applicants/me/resumes` is just sugar over it.

## Tests

**Unit** (`tests/unit/test_storage_local.py`)

- `save` then `read` returns the same bytes.
- `delete` removes the file and is idempotent (no error on second delete).
- `save` auto-creates any intermediate directories under `root`.
- `read` raises a clear error on missing key (the route maps it to 500; tested at the route layer).
- The `root` path is honored — files are written inside `root`, not elsewhere.

**Integration** (`tests/integration/test_resumes_upload.py`) — uses the existing savepoint-isolated session fixture + `tmp_path` for storage root:

1. **Happy path:** POST a small PDF → 201; the resume row exists in `kpa.resumes` with the right `applicant_id`, `content_type`, `size_bytes`; the file is on disk at the recorded `storage_key`; the bytes match.
2. **Unknown applicant:** POST to `/applicants/{random_uuid}/resumes` → 404.
3. **Disallowed content type:** POST with `text/plain` → 415; no row created; no file written.
4. **Oversized file:** POST a > 10 MB payload → 413; no row created; no file written. (Test uses a low cap via settings override to avoid generating real 10 MB payloads.)
5. **GET happy path:** create a resume, GET it → 200 with the same metadata the POST returned.
6. **GET unknown resume:** GET `/applicants/{aid}/resumes/{random_uuid}` → 404.
7. **GET resume from wrong applicant:** create a resume for applicant A, GET it from applicant B's URL → 404 (not 403, to avoid leaking the resume's existence).

## File layout after this slice

```
api/
├── .env.example                         # + KPA_STORAGE_ROOT, KPA_MAX_UPLOAD_BYTES, KPA_ALLOWED_RESUME_CONTENT_TYPES
├── .gitignore                           # + var/
├── pyproject.toml                       # + python-multipart (if not already pulled by FastAPI extras)
├── src/kpa/
│   ├── settings.py                      # + storage_root, max_upload_bytes, allowed_resume_content_types
│   ├── app_factory.py                   # + storage construction + app.state.storage + /resumes router mount
│   ├── integrations/
│   │   ├── __init__.py
│   │   └── storage/
│   │       ├── __init__.py
│   │       ├── base.py                  # Storage Protocol
│   │       └── local.py                 # LocalFileStorage
│   ├── db/
│   │   ├── models.py                    # + ResumeParseStatus + Resume
│   │   └── migrations/versions/0002_resumes.py
│   └── routes/
│       └── resumes.py                   # POST + GET handlers
└── tests/
    ├── unit/
    │   └── test_storage_local.py
    └── integration/
        └── test_resumes_upload.py
```

No new domain module yet. The route handler is small enough that extracting a service layer ahead of time would be premature; that refactor lands when the parse worker (which legitimately shares logic with the route) arrives.

## Out of scope (intentionally)

Each item below has its own plan slot:

- **Parse worker** (Celery `parse_resume` task; pypdf / pdfminer / python-docx extraction; LLM-assisted parse; `parsed_json` population) — next plan after this one.
- **Embedding generation** + `applicant_embeddings` / `job_embeddings` tables — pending Open Decision #2 (embedding dimension).
- **S3 storage impl** — interface is here; impl + deploy-target choice come together in P5.
- **Magic-byte content-type verification** + **ClamAV scan** — both deferred to the parse plan, which reads the bytes anyway.
- **`/v1/applicants/me/resumes`** alias — lands with the auth plan (Google OAuth, per 2026-05-16 decision).
- **List endpoint** (`GET /v1/applicants/{aid}/resumes`) + the supporting partial index — deferred until a UI surface needs it.
- **Download endpoint** (`GET /resumes/{id}/file`) — deferred; no consumer yet.

## Open follow-ups carried from the P0 DB-layer review

These are noted here so they don't get lost. They're not blocking this slice but should be addressed in a small cleanup plan before P1 grows too large:

- Make `settings` required (not `Settings | None = None`) in `create_engine_from_settings`.
- Migrate `@app.on_event("shutdown")` to FastAPI lifespan context manager.
- Tighten `test_users_has_partial_indexes` to assert the `WHERE deleted_at IS NULL` clause is actually present in `indexdef`.

The cleanup plan can land in parallel with the parse-worker plan since they don't touch the same files.
