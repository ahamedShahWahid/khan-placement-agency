# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

KPA (Khan Placement Agency) is an early-stage placement platform. The repo currently contains:

- `api/` — FastAPI backend (Python 3.12, `uv`-managed). Health/readiness probes, async SQLAlchemy + Alembic against Postgres 16, and the resume upload data plane. Auth, parsing, matching, and Celery workers are deferred to later plans.
- `IMPLEMENTATION_SPEC.md` — **how** we build it (the engineering spec; owner-authored, v0.2 MVP-first).
- `docs/prd/KPA_Enhanced_BRD_v1_1.pdf` — **what** we're building (product BRD/PRD; source of truth for scope).
- `docs/superpowers/plans/` and `docs/superpowers/specs/` — per-feature plans and design docs.

The Flutter mobile + web frontend described in the spec (§3) does not yet exist in this repo. The spec overrides the BRD's React Native + Next.js stack — see `~/.claude/projects/-Users-ahamadshah-ahamed-personal-kpa/memory/kpa-frontend-stack-flutter.md`.

When scope and "how" conflict, the BRD wins on product behavior; the spec wins on tech choices.

## Working directory note

Almost all backend commands run from `api/`, not the repo root. The `uv` workspace, `alembic.ini`, and `pyproject.toml` all live there. The README in `api/` is the most up-to-date reference for day-to-day commands; this file calls out only the non-obvious bits.

## Commands

```bash
# From api/
uv sync                                                   # install deps
uv run --env-file=.env uvicorn kpa.main:app --reload --port 8000

# Migrations (writes to KPA_DB_URL)
uv run alembic upgrade head
uv run alembic revision -m "describe the change"          # hand-edit; no --autogenerate by default
uv run alembic downgrade -1

# Tests
uv run pytest -v -m "not integration"                     # fast, no DB
uv run pytest -v -m integration                           # needs local Postgres + kpa_test DB
uv run pytest -v tests/unit/test_settings.py::test_db_url_rejects_sync_driver  # single test

# Lint / format / type-check
uv run ruff check src/ tests/
uv run ruff format src/ tests/
uv run mypy                                               # strict; src/kpa only, migrations excluded
```

Single-source for env vars is `api/.env` (copy from `.env.example`). Required: `KPA_ENV`, `KPA_SERVICE_NAME`, `KPA_DB_URL`. The app refuses to boot if any required var is missing or invalid (see `settings.py`).

`KPA_DB_URL` **must** use the `postgresql+asyncpg://` driver — this is enforced in `Settings._enforce_async_driver`.

## Architecture — non-obvious bits

### App wiring (`src/kpa/app_factory.py`)

`create_app()` builds a fresh app on every call so tests get full isolation. It owns the lifecycle of three things stored on `app.state`:

- `settings` — validated `Settings` instance.
- `db_engine` + `db_sessionmaker` — single async engine. The engine sets `search_path=kpa` via asyncpg `server_settings`, so model code does **not** need to repeat `schema="kpa"` on every query (the `Base.__table_args__` declares it once for DDL).
- `storage` — a `Storage` protocol implementation (currently `LocalFileStorage`).

Routes get these via FastAPI `Depends(...)` (`get_session`, `get_storage`) that read from `request.app.state`. This keeps routes thin and lets tests swap dependencies via `app.dependency_overrides`.

The engine is disposed on the FastAPI `shutdown` event. Don't create your own engine in module scope.

### Middleware — pure ASGI, not BaseHTTPMiddleware

`RequestIdMiddleware` (`middleware/request_id.py`) is implemented as a pure ASGI middleware on purpose. Starlette's `BaseHTTPMiddleware` wraps the inner app in an `anyio` task group, which makes asyncpg detect a mismatched event loop and raise `Future attached to a different loop` — both in tests and prod. **New middleware in this repo should follow the same pure-ASGI pattern** until something forces otherwise.

The request id is a uuid4. A client-supplied `X-Request-Id` is honored only if it parses as a valid uuid4; otherwise it's replaced. Every response (including problem+json errors) carries this header — it's the only correlation handle in the logs.

### Error handling — RFC 7807 problem+json

`middleware/error_handler.py` replaces FastAPI's default error shape. Both `HTTPException` and unhandled `Exception` flow through `_problem()` and produce `application/problem+json` with a `request_id` field. The unhandled-exception path explicitly re-attaches the `X-Request-Id` header because Starlette's `ServerErrorMiddleware` sits outside `RequestIdMiddleware` in the stack.

When you raise `HTTPException`, the `detail` becomes the user-visible `detail` field. Treat it as a user-facing string, not a debugging aid.

### Resume upload route invariants

`routes/resumes.py` enforces three invariants in this order:

1. Content-type whitelist (`KPA_ALLOWED_RESUME_CONTENT_TYPES`) — reject with 415.
2. Size cap (`KPA_MAX_UPLOAD_BYTES`, default 10 MiB) — reject with 413.
3. Applicant existence (live row, not soft-deleted) — 404.

The 404 detail string is **uniform** across "unknown applicant", "unknown resume", and "applicant/resume mismatch" cases (commit `ac9efdf` — avoid resume-id enumeration leak). Keep it that way when adding new lookup paths.

The storage key is set **after** the DB flush so we can name the blob `resumes/{resume.id}{ext}`. The extension comes from `_CONTENT_TYPE_TO_EXT` keyed off the validated content-type — never trust the uploaded filename's extension. There's no rollback compensation if the blob write fails after the row exists; for the MVP this is fine because we still own the DB cleanup, but be aware before adding S3.

### Soft delete model

Every domain table carries `id` (uuid4), `created_at`, `updated_at`, `deleted_at TIMESTAMPTZ NULL`. Live-row queries must filter `deleted_at IS NULL`. Uniqueness is enforced via partial indexes `WHERE deleted_at IS NULL` (see `User.ix_users_email_live`, etc.). When you add a new table, follow this pattern — the `CreatedAt` / `UpdatedAt` / `DeletedAt` `Annotated` types in `db/models.py` are reusable.

The `Base.__table_args__` is typed `Any` and uses `# noqa: RUF012` because SQLAlchemy's declarative base types this as a class-level mutable. Don't "fix" the noqa.

### Don't reuse models as response schemas

Per spec §4.2 and the comment in `db/models.py`: SQLAlchemy models are never response models. Define `*Read` / `*Create` / `*Update` Pydantic v2 models in the route module (see `ResumeRead` with `ConfigDict(from_attributes=True)` for the conversion pattern).

## Test patterns

### Two-conftest design

`tests/conftest.py` provides a `client` fixture that uses a **fake DSN** (`postgresql+asyncpg://u:p@h:5432/d`) — the app boots but no DB connection is opened. This is what unit tests use; they never touch Postgres.

`tests/integration/conftest.py` shadows that fixture with a real-Postgres version that uses savepoint-based rollback isolation: each test gets a session bound to a connection that holds an outer transaction; `join_transaction_mode="create_savepoint"` lets test code call `await session.commit()` without escaping the outer txn; teardown rolls back. **No truncation between tests.** The migrations run once per test session.

A `pytestmark = pytest.mark.integration` at the top of the integration conftest tags every test under that directory. There's no need to mark individual integration tests.

### TestClient vs httpx.AsyncClient

The integration conftest provides two HTTP clients:

- `client` (sync `TestClient`) — fine for routes that don't share the `session` fixture's connection. TestClient runs the ASGI app via Starlette's blocking portal in a **separate event loop**, which conflicts with asyncpg connections bound to the pytest-asyncio test loop.
- `async_client` (`httpx.AsyncClient` + `ASGITransport`) — required whenever the test asserts on DB state through the shared `session` fixture (e.g., `test_resumes_upload.py`). It executes the ASGI app on the same event loop as the test.

If you write a new integration test that exercises both an HTTP endpoint and `session.execute(...)`, default to `async_client`.

### NullPool for the integration engine

The per-test engine in the integration conftest uses `poolclass=NullPool` to force a fresh asyncpg connection bound to the current test's event loop. Without it, asyncpg connections from earlier tests get reused and raise the loop-mismatch error. Keep it.

## Conventions worth knowing

- **uv only.** Don't `pip install` — it bypasses `uv.lock` and breaks reproducibility.
- **No Docker for MVP.** Local Postgres is Homebrew (`postgresql@16`). Containers re-enter at the deploy-target step (spec §11.1 / §13 P5).
- **Hand-written migrations.** Alembic autogenerate is intentionally off until the model surface gets bigger (~10 tables). Edit the generated revision file before running `upgrade head`.
- **Migrations live in `src/kpa/db/migrations/versions/`** and are excluded from mypy.
- **structlog only.** No `print`, no `logging.getLogger(...).info(f"...")`. Use `structlog.get_logger(__name__)` and pass context as kwargs. Output is plain key=value by default; flip `KPA_LOG_FORMAT=json` for prod (Fluent Bit → Elasticsearch).
- **All handlers `async def`.** Per spec §4.2.
- **Versioned routes mount under `/v1`**, except `/health` and `/ready` which are bare so ALB/k8s probes can hit them directly.

## Source-of-truth files when in doubt

- API conventions and roadmap → `IMPLEMENTATION_SPEC.md` (§4 backend, §5 data model, §6 pipelines, §10 API design, §11 infra).
- Product scope → `docs/prd/KPA_Enhanced_BRD_v1_1.pdf`.
- Active per-feature work → `docs/superpowers/plans/` (most recent file = current focus).
