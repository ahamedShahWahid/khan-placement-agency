# P4 Sub-project A — `audit_logs` substrate

**Status:** approved 2026-05-28
**Owner:** backend
**Scope:** sub-project A of three approved P4 slices (A → B → C). Sub-project D (DSR delete) was scoped at brainstorming-time as "hard-delete PII, keep anonymized aggregates" — that constraint shapes the audit row's tombstone-survival requirement (see §6 below).

## 1. Why this slice exists

The current codebase emits one structured-log line that is *load-bearing for DPDP compliance*:

```
api/src/kpa/routes/applications.py
  _log.info("recruiter.resume-accessed", request_id=..., recruiter_user_id=...,
            employer_id=..., application_id=..., applicant_id=..., resume_id=...)
```

The CLAUDE.md comment beside it states explicitly: *"this is the audit-trail seed for P4 DPDP; an `audit_logs` table is deferred."* Six P4 sub-projects (consent grant/revoke, DSR export request/complete, DSR delete, admin moderation, MFA enrollment, recruiter access) all need an append-only event store. Inventing six different log shapes is not viable; promoting the seed line into a real table is.

Structured logs in Kibana are **observability**. The `audit_logs` table is **evidence** — joinable, retainable, queryable through the API, and provable to a regulator.

## 2. Non-goals

- Backfilling historical structured-log lines into `audit_logs` rows. The structured log is the only record of pre-P4 events; it stays in Elasticsearch.
- An admin-facing UI to browse audit rows. That lives in the admin-moderation sub-project (P4 admin).
- A retention/TTL policy. Indefinite retention until the table grows past ~10M rows; deferred to a `purge_old_audit_logs` Celery beat task when needed.
- Tamper-evidence (hash chains, signed rows). Not a DPDP-Act-2023 requirement; appropriate for a follow-up if a regulator asks.
- Cross-table referential integrity beyond `actor_user_id → users.id`. `resource_id` is intentionally **un-FK'd** because it points at many different tables.

## 3. Table shape

```sql
CREATE TABLE kpa.audit_logs (
    id              UUID PRIMARY KEY,
    actor_user_id   UUID NULL REFERENCES kpa.users(id) ON DELETE SET NULL,
    actor_role      TEXT NOT NULL,
    action          TEXT NOT NULL,
    resource_type   TEXT NULL,
    resource_id     UUID NULL,
    context         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ix_audit_logs_actor_created
    ON kpa.audit_logs (actor_user_id, created_at DESC);
CREATE INDEX ix_audit_logs_resource_created
    ON kpa.audit_logs (resource_type, resource_id, created_at DESC);
CREATE INDEX ix_audit_logs_action_created
    ON kpa.audit_logs (action, created_at DESC);
```

### 3.1 Column-by-column rationale

| Column | Rationale |
|---|---|
| `id` | UUID4 per repo convention. PK; queries don't seek by id but the GUID is a useful external handle for support tickets. |
| `actor_user_id` | FK to `users.id`. **Nullable** because system actions (Celery beat sweeps, cron) have no user. **`ON DELETE SET NULL`** — see §6 (DSR-delete must succeed without leaving dangling FKs, but the audit row itself MUST NOT disappear). |
| `actor_role` | Snapshot of the role at action time (`'applicant'`/`'recruiter'`/`'admin'`/`'system'`). If a user's role flips later (e.g., applicant→recruiter via `POST /v1/employers`), the audit history still shows the role they had **then**. Plain TEXT, not an enum, because `'system'` is not in the `UserRole` StrEnum and we don't want to enum-evolve for every future actor class. |
| `action` | Dotted, lowercase, verb-past-tense slug. See §4 for the namespace. Plain TEXT; if/when the set stabilizes we can convert to a Postgres enum (mirrors the `applications.source` follow-up noted in CLAUDE.md). |
| `resource_type` | What was acted on (`'resume'`, `'application'`, `'job'`, `'user'`, `'consent'`, `'employer'`, ...). Nullable for actions with no single target (e.g., `'admin.bulk_sweep'`). |
| `resource_id` | UUID of the row. Deliberately not a FK — points at many tables. The `(resource_type, resource_id, created_at desc)` index makes "what happened to resume X" a single seek. |
| `context` | Arbitrary structured payload. Mandatory keys: `request_id` (string). Optional: `client_ip`, `user_agent`, action-specific keys (e.g., `from_status`, `to_status` for state transitions). `NOT NULL DEFAULT '{}'` so callers never have to write `{}` explicitly. |
| `created_at` | TIMESTAMPTZ + server `now()`. Audit rows time-stamp by **DB clock**, not app clock — closer to the real event, cheaper to reason about across pods. |

### 3.2 What's deliberately missing

- **No `updated_at`.** A row that can be updated is not an audit log.
- **No `deleted_at`.** Same reasoning. The codebase's `CreatedAt`/`UpdatedAt`/`DeletedAt` `Annotated` types from `db/models.py` are **not used** here — this is the documented exception. Live-row queries elsewhere filter `deleted_at IS NULL`; queries against `audit_logs` never do.
- **No idempotency key.** Replays from a retried Celery task WILL produce multiple rows — that's evidence that a retry happened, which is itself audit-worthy. Deduping is the consumer's problem (admin UI can `GROUP BY action, resource_id, date_trunc('minute', created_at)` if it wants).

### 3.3 Indexes

Three composite indexes covering the three query patterns each P4 sub-project will need:

1. `(actor_user_id, created_at DESC)` — "show me everything user X did, newest first." Powers admin/user history views.
2. `(resource_type, resource_id, created_at DESC)` — "show me everything that ever happened to resource R." Powers DSR-export's per-resource history dumps.
3. `(action, created_at DESC)` — "all DSR exports last week" / "all `admin.user.suspended` events this month." Powers compliance reports.

No partial-UNIQUE indexes — rows are not deduped (see §3.2). No `WHERE ...` predicates because the table has no soft-delete column to filter on.

## 4. Action-slug namespace

Slugs are `lowercase.dot.separated.verb_past_tense`. Reserve top-level prefixes now so the namespace stays orderly:

| Prefix | Owner sub-project | Examples |
|---|---|---|
| `resume.*` | A (this slice) + future | `resume.accessed`, future `resume.deleted` |
| `application.*` | future | `application.created`, `application.withdrawn` |
| `job.*` | future | `job.created`, `job.deleted`, `admin.job.unpublished` |
| `consent.*` | B | `consent.granted`, `consent.revoked` |
| `user.*` | C, D | `user.dsr_export_requested`, `user.dsr_export_completed`, `user.dsr_deleted` |
| `admin.*` | future | `admin.user.suspended`, `admin.job.unpublished` |
| `auth.*` | future | `auth.mfa.enrolled`, `auth.refresh.revoked` |
| `employer.*` | future | `employer.verified`, `employer.created` |

This slice ships **one** slug: `resume.accessed`. The namespace is documented in CLAUDE.md so future PRs follow it.

## 5. Helper API

`src/kpa/audit/__init__.py`:

```python
async def audit_log(
    session: AsyncSession,
    *,
    action: str,
    actor: User | None,
    actor_role: str | None = None,
    resource_type: str | None = None,
    resource_id: UUID | None = None,
    context: dict[str, Any] | None = None,
) -> AuditLog:
    """Append a row to audit_logs. Caller owns the transaction.

    The row commits-or-rolls-back with the caller's business action — there is
    NO commit, NO flush-and-discard, NO fire-and-forget dispatch. If the
    business action rolls back, the audit row rolls back too. That is the
    contract.

    actor_role is normally derived from actor.role; pass it explicitly for
    'system' actors (where actor is None) or when the role needs to differ
    from the actor's current role (rare).
    """
```

### 5.1 Why caller-owns-the-txn (and not fire-and-forget Celery)

A Celery dispatch decouples the audit row from the business txn. That sounds robust until you consider the failure modes:

- Business txn commits, Celery broker is down → no audit row → **evidence loss**.
- Business txn rolls back, Celery dispatch already happened → audit row written for an event that didn't occur → **false evidence**.

Both are unacceptable for DPDP evidence. Caller-owns-the-txn makes the audit row exactly as durable as the business row it describes — which is the strongest guarantee we can offer.

### 5.2 Why the helper returns the `AuditLog` row

For tests, mostly — `await audit_log(...)` returning the row lets tests assert on the created row id without re-querying. Production callers can discard the return value.

### 5.3 Error handling

The helper does NOT swallow exceptions. If `session.flush()` fails (FK violation on `actor_user_id`, etc.), the exception propagates to the caller — which is what we want, because that caller's business txn should ALSO fail (the audit row is part of its atomic unit).

## 6. Interaction with future DSR-delete (sub-project D)

Sub-project D was scoped at brainstorm-time as **"hard-delete PII, keep anonymized aggregates."** That choice has one consequence for THIS slice:

- `users` rows will be hard-deleted by DSR.
- `audit_logs.actor_user_id` is FK'd to `users.id` with `ON DELETE SET NULL`.
- After DSR-delete: the audit row's `actor_user_id` becomes NULL, but `actor_role` and the `context.user_id_at_action_time` we record there still tell the regulator "an applicant did X at time T." Re-identification of the now-deleted user is intentionally impossible — that's the DPDP guarantee.

**The audit row itself is never deleted by DSR.** Audit logs are evidence-of-process, not personal data. A regulator audit of "what happened to user X's data" needs the rows to survive the user record being gone.

This is the load-bearing reason for `ON DELETE SET NULL` instead of `ON DELETE CASCADE`. Worth noting in CLAUDE.md so future migrations don't "fix" the FK to CASCADE.

## 7. Integration in this slice — `routes/applications.py`

The single integration point. Inside `get_application_resume`:

```python
# Existing structured log stays — Kibana still consumes it.
_log.info(
    "recruiter.resume-accessed",
    request_id=request_id,
    recruiter_user_id=str(current_user.id),
    employer_id=str(employer_id),
    application_id=str(application_id),
    applicant_id=str(applicant.id),
    resume_id=str(resume.id),
)

# New: durable audit row, committed in the same txn as the resume fetch.
await audit_log(
    session,
    action="resume.accessed",
    actor=current_user,
    resource_type="resume",
    resource_id=resume.id,
    context={
        "request_id": request_id,
        "application_id": str(application_id),
        "applicant_id": str(applicant.id),
        "employer_id": str(employer_id),
    },
)
```

The structured log is **kept**, not replaced. Reason: Fluent Bit → Elasticsearch is the live operational channel (PagerDuty filters, on-call queries); the DB row is the *durable* channel. Removing the structlog line would break ops dashboards that already filter on `recruiter.resume-accessed`.

## 8. Settings, env, infra

None. No new env vars. No new Celery queue. No new external dependency. The table lives in the existing `kpa` schema with the existing engine.

## 9. Testing

Three layers:

1. **Unit test (`tests/unit/audit/test_helper_signature.py`)** — the helper accepts `actor=None` + explicit `actor_role='system'`; raises `TypeError` if `actor_role` is omitted AND `actor` is None. Pure signature/contract test, no DB.

2. **Integration test (`tests/integration/test_audit_logs.py`)** —
   - happy path: write a row, query by `(resource_type, resource_id)`, assert shape.
   - txn rollback: helper writes in a sub-savepoint that the test rolls back; assert the row is gone.
   - actor=None / actor_role='system': writes successfully.
   - FK on actor_user_id violates when the user doesn't exist — helper propagates the IntegrityError.

3. **Integration test (`tests/integration/test_resumes_recruiter_audit.py`)** — augment the existing recruiter-resume-access happy-path test (already in `test_recruiter_resume_access.py`) to assert ONE `audit_logs` row was written with `action='resume.accessed'`, the expected `resource_id`, and the request_id propagated into `context`. Also: simulate a failure AFTER the audit row insert (raise inside the route handler post-flush) → assert the audit row is rolled back.

## 10. CLAUDE.md doc updates

Add a new top-level section under "Architecture — non-obvious bits":

```
### Audit logs

- **Append-only** table; no UPDATE/DELETE paths in code. `Annotated` types
  from `db/models.py` for `created_at`/`updated_at`/`deleted_at` are
  deliberately NOT used here.
- **Caller owns the txn.** `await audit_log(session, ...)` participates in
  the caller's transaction; no commit, no fire-and-forget. The row is as
  durable as the business action it records.
- **`actor_user_id` is `ON DELETE SET NULL`.** Load-bearing for DSR-delete
  (sub-project D): hard-deleting the user must succeed, but the audit row
  itself survives — re-identification is impossible by design.
- **Action-slug namespace:** dotted, lowercase, verb-past
  (`resume.accessed`, `consent.granted`, `user.dsr_deleted`). Reserved
  prefixes: see audit-logs spec §4.
- **The structlog line stays.** Fluent Bit / Kibana / PagerDuty consume the
  structured log; the DB row is the durable, queryable record. They are
  complementary, not substitutes.
```

## 11. Out of scope (call-outs)

- An admin endpoint to query audit rows (deferred to admin-moderation sub-project).
- Bulk export of audit rows (deferred to DSR-export — sub-project C — which will dump per-user-id history).
- Tamper-evidence / hash chains.
- Retention TTL.

## 12. Acceptance

- `0013_audit_logs.py` migration upgrades + downgrades cleanly.
- `AuditLog` model declared in `db/models.py` without `CreatedAt`/`UpdatedAt`/`DeletedAt`-annotated types.
- `audit_log()` helper signature matches §5; tests in §9 all pass.
- `routes/applications.py:get_application_resume` writes one `audit_logs` row per successful recruiter resume access.
- CLAUDE.md updated per §10.
- All existing tests still pass.
