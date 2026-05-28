# Recruiter Jobs CRUD (sub-project H) — Design

**Date:** 2026-05-28
**Status:** Approved (design)
**Owner area:** `api/` (backend only — no Flutter changes this slice)

## Goal

Open the recruiter persona end-to-end at the HTTP layer: a Google-signed-in user
can become a recruiter by claiming/creating an employer, post and edit jobs for
that employer, list their employer's jobs with applicant counts, see who
applied to each job (with match score + LLM explanation), and download the
resume of any applicant who applied to one of their jobs.

This closes the gap left by P2.0 (which deferred recruiter HTTP CRUD; jobs land
via the seed CLI only) and unblocks any future recruiter UI without committing
to one in this slice.

BRD §2 (Recruiter Workflow); `IMPLEMENTATION_SPEC.md` §13 P2 "Recruiter direct
posting" line item.

## Background — verified current state

- `employers` table exists with columns `id, name, name_norm, website,
  verified_at, created_at, updated_at, deleted_at` and a partial UNIQUE index
  on `name_norm` WHERE `deleted_at IS NULL`. Seeded via `kpa-seed-jobs` CLI.
- `jobs` table exists with `id, employer_id, title, description, locations
  (text[]), min_exp_years, max_exp_years, ctc_max, status, created_at,
  updated_at, deleted_at`. `status` is a `VARCHAR` carrying `'open'|'closed'`
  today. Seed CLI is the only writer.
- `users.role` is a Python enum (`UserRole`) with values `APPLICANT, RECRUITER,
  ADMIN`. Today `AuthService._upsert_identity` provisions every new Google
  sign-in with `role=APPLICANT`. No mechanism elevates to `RECRUITER`.
- `routes/jobs.py` exposes only `GET /v1/jobs/{id}` (applicant-side view).
  Returns a uniform 404 across unknown/closed/soft-deleted, by design.
- `routes/feed.py` filters on `jobs.status='open'` AND `jobs.deleted_at IS NULL`.
- `routes/applications.py` exposes apply/withdraw/list-mine for applicants.
  `applications.status` is `'applied'|'withdrawn'`.
- `routes/resumes.py` is applicant-only (`/v1/applicants/me/resumes/...`) with
  a 4-step error ladder: 401 → 403 not_an_applicant → 415/413 → 404 uniform.
- `embed_job.delay(job_id)` is the existing post-commit fire-and-forget
  pattern (broad `except Exception` + `_log.warning("embed.dispatch-failed",
  exc_info=True)`) used by the seed CLI.
- `_require_applicant` lives inline in `routes/resumes.py`, `routes/feed.py`,
  and `routes/jobs.py` (duplicated by intent; the resumes copy has different
  downstream semantics — see CLAUDE.md).
- `match_explanations` already live in `matches.explanation` JSONB
  (`{fit, caveat, generator, generator_version}`).

## Decisions (confirmed with owner)

1. **Self-service identity flow.** `POST /v1/employers` creates an employer,
   creates an `employer_users(owner)` link, and flips the caller's
   `users.role` from `APPLICANT` to `RECRUITER` in one transaction. No admin
   endpoint; no email-domain allowlist.
2. **Many-to-many employer↔user link.** New `employer_users(employer_id,
   user_id, role)` table with partial-UNIQUE on the pair. `role` is
   `'owner'|'member'`; only `owner` is used in this slice (invite flow is
   deferred).
3. **Full recruiter surface in scope.** Identity + Jobs CRUD + applicants-
   per-job listing + per-application resume download — all four ship together.
4. **Re-embed only on content change.** PATCH that touches
   `title|description|locations|min_exp_years|max_exp_years|ctc_max` re-
   dispatches `embed_job.delay(job_id)`. Status-only PATCH does not.
5. **`status='closed'` ≠ soft-delete.** Closed = filled/expired, still visible
   in saved/applications history for applicants. Soft-delete (`deleted_at`) =
   posted in error, hidden everywhere. Both are reachable from the recruiter
   surface; only soft-delete uses `DELETE`.
6. **Unverified employers still surface in `/v1/feed`.** Adding admin
   verification gating without admin tooling would make the slice undemoable.
   `JobRead` gains `employer_verified: bool` so a future "verified-only" feed
   filter is a one-line change.
7. **Resume-access audit lives in structured logs.** A `recruiter.resume-
   accessed` log event with `{request_id, recruiter_user_id, employer_id,
   application_id, applicant_id, resume_id}` is the audit trail. An
   `audit_logs` table is deferred to P4 (DPDP).

## Architecture

```
db/migrations/versions/0008_*.py
  + employer_users(id uuid pk, employer_id uuid fk, user_id uuid fk,
                   role varchar, created_at, updated_at, deleted_at,
                   PARTIAL UNIQUE (employer_id, user_id) WHERE deleted_at IS NULL)
  + employers.created_by_user_id (uuid fk users.id, nullable)
  No change to jobs / users (UserRole enum already has RECRUITER).

db/models.py
  + EmployerUser model + relationships on Employer + User.
  + Employer.created_by_user_id column.

auth/dependencies.py
  + _require_recruiter(user) -> User                  (mirrors _require_applicant)
  + _require_recruiter_at_employer(user, employer_id, session) -> None

routes/employers.py                                   (new file)
  POST /v1/employers          → 201 EmployerRead
  GET  /v1/employers/me       → 200 list[EmployerRead]

routes/jobs.py                                        (extended)
  POST   /v1/jobs                              → 201 JobRead
  PATCH  /v1/jobs/{id}                         → 200 JobRead
  DELETE /v1/jobs/{id}                         → 204
  GET    /v1/jobs/me                           → 200 PagedRecruiterJobs
  GET    /v1/jobs/{id}/applicants              → 200 PagedApplicantOfJob

routes/applications.py                                (extended)
  GET /v1/applications/{application_id}/resume → 200 binary blob
```

### Data model — `employer_users`

```python
class EmployerUser(Base):
    __tablename__ = "employer_users"

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    employer_id: Mapped[UUID] = mapped_column(ForeignKey("kpa.employers.id"), nullable=False)
    user_id: Mapped[UUID] = mapped_column(ForeignKey("kpa.users.id"), nullable=False)
    role: Mapped[str] = mapped_column(String(16), nullable=False)  # 'owner'|'member'
    created_at: Mapped[CreatedAt]
    updated_at: Mapped[UpdatedAt]
    deleted_at: Mapped[DeletedAt]

    __table_args__ = (
        Index(
            "ix_employer_users_pair_live",
            "employer_id", "user_id",
            unique=True,
            postgresql_where=text("deleted_at IS NULL"),
        ),
        Index("ix_employer_users_user", "user_id", postgresql_where=text("deleted_at IS NULL")),
    )
```

`Employer.created_by_user_id` is informational (audit/UX, e.g. "you created
this"); it does not gate access. The `employer_users` row is the only
authority for "can act on this employer".

### Identity flow (POST /v1/employers)

Single SQLAlchemy transaction:

```python
async def create_employer(payload, user, session):
    name_norm = _normalize(payload.name)  # lower + collapse whitespace + trim
    try:
        emp = Employer(
            name=payload.name,
            name_norm=name_norm,
            website=str(payload.website) if payload.website else None,
            created_by_user_id=user.id,
        )
        session.add(emp)
        await session.flush()  # surfaces IntegrityError now for clean error mapping
    except IntegrityError as e:
        if _is_unique_violation(e, "ix_employers_name_norm_live"):
            raise HTTPException(409, detail="employer_name_taken")
        raise

    session.add(EmployerUser(employer_id=emp.id, user_id=user.id, role="owner"))

    # Role flip: APPLICANT -> RECRUITER. Bounded; never demote ADMIN.
    await session.execute(
        update(User)
        .where(User.id == user.id, User.role == UserRole.APPLICANT)
        .values(role=UserRole.RECRUITER, updated_at=func.now())
    )
    await session.commit()
    await session.refresh(emp)
    return EmployerRead.model_validate(emp)
```

The `_is_unique_violation` helper inspects `e.orig.diag.constraint_name` on the
asyncpg cause (works for the partial UNIQUE index). On any other
`IntegrityError`, re-raise — the unhandled handler maps it to 500.

### RBAC

```python
# auth/dependencies.py — new helpers
async def _require_recruiter(user: User = Depends(current_user)) -> User:
    if user.role != UserRole.RECRUITER:
        raise HTTPException(403, detail="not_a_recruiter")
    return user

async def _require_recruiter_at_employer(
    user: User,
    employer_id: UUID,
    session: AsyncSession,
) -> None:
    row = await session.scalar(
        select(EmployerUser.id).where(
            EmployerUser.employer_id == employer_id,
            EmployerUser.user_id == user.id,
            EmployerUser.deleted_at.is_(None),
        )
    )
    if row is None:
        # Uniform 404 for jobs routes; 403 for /v1/employers/me (won't reach this helper).
        raise HTTPException(404, detail="not found")
```

The "not at employer" 404 is uniform with the existing pattern: never leak
whether an id exists for another tenant.

### Re-embed on edit

```python
_EMBED_TRIGGERING_FIELDS = frozenset({
    "title", "description", "locations",
    "min_exp_years", "max_exp_years", "ctc_max",
})

async def patch_job(job_id, payload, ...):
    job = await _load_for_recruiter(job_id, user, session)  # 404-or-job

    fields = payload.model_dump(exclude_unset=True)
    if "status" in fields and fields["status"] not in {"open", "closed"}:
        raise HTTPException(400, detail="invalid_transition")

    content_changed = bool(_EMBED_TRIGGERING_FIELDS & fields.keys())

    for k, v in fields.items():
        setattr(job, k, v)
    await session.commit()
    await session.refresh(job)

    if content_changed:
        try:
            embed_job.delay(str(job.id))
        except Exception:
            _log.warning("embed.dispatch-failed", job_id=str(job.id), exc_info=True)

    return JobRead.from_orm_with_employer(job)
```

### Counts query for `GET /v1/jobs/me`

Single query, no N+1:

```python
stmt = (
    select(
        Job,
        func.count(distinct(Application.id)).label("applicant_count"),
        func.count(
            distinct(case((Match.surfaced_at.is_not(None), Match.id)))
        ).label("surfaced_match_count"),
    )
    .join(EmployerUser, EmployerUser.employer_id == Job.employer_id)
    .outerjoin(Application, and_(
        Application.job_id == Job.id,
        Application.deleted_at.is_(None),
        Application.status == "applied",
    ))
    .outerjoin(Match, and_(
        Match.job_id == Job.id,
        Match.deleted_at.is_(None),
    ))
    .where(
        EmployerUser.user_id == user.id,
        EmployerUser.deleted_at.is_(None),
        Job.deleted_at.is_(None),
        # status filter applied below
    )
    .group_by(Job.id)
    .order_by(Job.created_at.desc(), Job.id.desc())
)
if status_filter == "open":
    stmt = stmt.where(Job.status == "open")
# (`?status=closed` would include both; deleted is never surfaced)
```

`applicant_count` counts only `status='applied'` rows (withdrawn applications
don't count as live applicants). `surfaced_match_count` counts matches that
crossed threshold and were surfaced — same semantics as `/v1/feed`.

### Applicants-per-job + resume access

```python
# GET /v1/jobs/{job_id}/applicants
# Returns each live application + the matching Match row (if any).
stmt = (
    select(Application, User, Match)
    .join(User, User.id == Application.applicant_id)  # applicant user row
    .outerjoin(Match, and_(
        Match.applicant_id == Application.applicant_id,
        Match.job_id == Application.job_id,
        Match.deleted_at.is_(None),
    ))
    .where(
        Application.job_id == job_id,
        Application.deleted_at.is_(None),
        Application.status == "applied",
        # cursor + ordering
    )
    .order_by(Application.created_at.desc(), Application.id.desc())
    .limit(limit + 1)
)
```

Cursor encoding mirrors `/v1/feed`: opaque base64 of `{created_at, application_id}`.

Resume download lives in `routes/applications.py` (extended):

```python
# GET /v1/applications/{application_id}/resume
async def download(application_id, user, session, storage):
    user = await _require_recruiter(user)
    # Uniform 404: unknown application / wrong-employer / soft-deleted job / no resume
    row = await session.execute(
        select(Application, Job, Resume)
        .join(Job, Job.id == Application.job_id)
        .join(EmployerUser, and_(
            EmployerUser.employer_id == Job.employer_id,
            EmployerUser.user_id == user.id,
            EmployerUser.deleted_at.is_(None),
        ))
        .outerjoin(Resume, and_(
            Resume.applicant_id == Application.applicant_id,
            Resume.deleted_at.is_(None),
        ))
        .where(
            Application.id == application_id,
            Application.deleted_at.is_(None),
            Job.deleted_at.is_(None),
        )
        .order_by(Resume.created_at.desc())
    )
    first = row.first()
    if first is None or first.Resume is None:
        raise HTTPException(404, detail="not found")

    app, job, resume = first
    _log.info(
        "recruiter.resume-accessed",
        recruiter_user_id=str(user.id),
        employer_id=str(job.employer_id),
        application_id=str(app.id),
        applicant_id=str(app.applicant_id),
        resume_id=str(resume.id),
    )

    return StreamingResponse(
        storage.open(resume.storage_key),
        media_type=resume.content_type,
        headers={"Content-Disposition": f'attachment; filename="{resume.original_filename}"'},
    )
```

If the applicant has multiple resumes, the **latest** is returned (ORDER BY
`created_at DESC` + LIMIT 1 via the `.first()` on the joined query).

## Pydantic DTOs

```python
# In routes/employers.py
class EmployerCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str = Field(min_length=2, max_length=200)
    website: HttpUrl | None = None

class EmployerRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    name: str
    website: str | None
    verified_at: datetime | None
    created_at: datetime

# In routes/jobs.py — JobCreate, JobPatch, JobRead (existing JobRead gains employer_verified: bool)
class JobCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    employer_id: UUID
    title: str = Field(min_length=2, max_length=200)
    description: str = Field(min_length=10, max_length=10_000)
    locations: list[str] = Field(min_length=1, max_length=20)
    min_exp_years: int = Field(ge=0, le=50)
    max_exp_years: int = Field(ge=0, le=50)
    ctc_max: Decimal | None = Field(default=None, ge=0)
    status: Literal["open", "closed"] = "open"

class JobPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = Field(default=None, min_length=10, max_length=10_000)
    locations: list[str] | None = Field(default=None, min_length=1, max_length=20)
    min_exp_years: int | None = Field(default=None, ge=0, le=50)
    max_exp_years: int | None = Field(default=None, ge=0, le=50)
    ctc_max: Decimal | None = Field(default=None, ge=0)
    status: Literal["open", "closed"] | None = None

class RecruiterJobRow(JobRead):
    applicant_count: int
    surfaced_match_count: int

class ApplicantOfJobRow(BaseModel):
    application_id: UUID
    applicant_id: UUID
    display_name: str | None
    email: str
    status: str
    applied_at: datetime
    match_score: float | None
    match_explanation: dict[str, str] | None
```

Cross-field validation (`max_exp_years >= min_exp_years`) lives in a
`@model_validator(mode="after")` on both `JobCreate` and `JobPatch` (latter
only enforces when both are present in the patch).

## Migration 0008

Hand-edited (no autogenerate per CLAUDE.md):

```python
def upgrade() -> None:
    op.add_column(
        "employers",
        sa.Column("created_by_user_id", postgresql.UUID(as_uuid=True), nullable=True),
        schema="kpa",
    )
    op.create_foreign_key(
        "fk_employers_created_by_user_id",
        "employers", "users",
        ["created_by_user_id"], ["id"],
        source_schema="kpa", referent_schema="kpa",
    )

    op.create_table(
        "employer_users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("employer_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("role", sa.String(16), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["employer_id"], ["kpa.employers.id"], name="fk_employer_users_employer_id"),
        sa.ForeignKeyConstraint(["user_id"], ["kpa.users.id"], name="fk_employer_users_user_id"),
        sa.CheckConstraint("role IN ('owner','member')", name="ck_employer_users_role"),
        schema="kpa",
    )
    op.create_index(
        "ix_employer_users_pair_live",
        "employer_users",
        ["employer_id", "user_id"],
        unique=True,
        postgresql_where=sa.text("deleted_at IS NULL"),
        schema="kpa",
    )
    op.create_index(
        "ix_employer_users_user",
        "employer_users",
        ["user_id"],
        postgresql_where=sa.text("deleted_at IS NULL"),
        schema="kpa",
    )

def downgrade() -> None:
    op.drop_index("ix_employer_users_user", table_name="employer_users", schema="kpa")
    op.drop_index("ix_employer_users_pair_live", table_name="employer_users", schema="kpa")
    op.drop_table("employer_users", schema="kpa")
    op.drop_constraint("fk_employers_created_by_user_id", "employers", schema="kpa", type_="foreignkey")
    op.drop_column("employers", "created_by_user_id", schema="kpa")
```

## Error ladder (per recruiter-mutation route)

```
1. 401  Bearer parsing + JWT + user re-fetch                 (current_user)
2. 403  not_a_recruiter            (_require_recruiter)
3. 404  uniform                    (unknown id / other-employer / soft-deleted job)
4. 422  validation                 (Pydantic on body)
5. 200/201/204 success
```

`not_a_recruiter` ordered **before** any id-driven DB lookup so an applicant
never gets to probe id existence. `not_at_employer` is collapsed into the
uniform 404 (jobs routes); only `/v1/employers/me` returns 403 directly,
because its semantics don't include an id lookup.

## Idempotency / concurrency

- `POST /v1/employers` race on duplicate `name_norm` → partial UNIQUE catches
  it at flush time → 409 `employer_name_taken`. No auto-join.
- Role flip is a bounded UPDATE (`WHERE id=? AND role='APPLICANT'`) — never
  demotes ADMIN; idempotent for an already-RECRUITER user.
- `PATCH /v1/jobs/{id}` uses no optimistic lock (no `version` column).
  Last-write-wins is acceptable for the recruiter team sizes in MVP; can add
  a `version` field later without changing the API shape.
- `DELETE /v1/jobs/{id}` is idempotent: `UPDATE ... WHERE id=? AND deleted_at
  IS NULL` returns 204 whether 0 or 1 rows are affected.

## Testing

### Unit (`tests/unit/`)
- `test_employer_validators.py` — `name_norm` lowercase/whitespace folding;
  name length bounds enforced.
- `test_recruiter_dtos.py` — `JobPatch` `extra='forbid'`; cross-field
  `max_exp_years >= min_exp_years`; `JobRead.employer_verified` derivation.

### Integration (`tests/integration/`) — eight new files

1. **`test_employers_create.py`** — happy path role flip; 409 on duplicate
   `name_norm`; idempotent re-call by an already-RECRUITER user creates a
   *second* employer + a new `employer_users` row; never demotes ADMIN.
2. **`test_employers_me.py`** — recruiter sees own employers; applicant gets
   403 `not_a_recruiter`; soft-deleted `employer_users` row is excluded.
3. **`test_jobs_create_recruiter.py`** — 201 on owned-employer; 404 not-at-
   employer; 422 on invalid exp band / negative ctc; embed_job dispatched
   post-commit (assert dispatch via the existing `patched_embedding_provider`
   tracking).
4. **`test_jobs_patch.py`** — content edit re-embeds; status-only edit does
   NOT re-embed (assert dispatch call count); `open↔closed` both ways;
   invalid status value → 400 `invalid_transition`; uniform 404 for unknown /
   other-employer; PATCH that combines content + status re-embeds once.
5. **`test_jobs_delete.py`** — soft-delete hides job from `/v1/feed`,
   `/v1/jobs/{id}` (uniform 404), `/v1/jobs/me`; existing
   applications/saved entries remain queryable for the applicant; idempotent
   re-delete is 204.
6. **`test_jobs_me_listing.py`** — counts correct (assert no N+1 via
   `event.listen` on `Engine.before_cursor_execute` — total queries ≤ 3:
   auth, count, page); cursor pagination; closed hidden by default;
   `?status=closed` includes them; deleted is never surfaced.
7. **`test_jobs_id_applicants.py`** — happy path with three applicants;
   ordering by `applied_at DESC, id DESC`; uniform 404 for unknown /
   other-employer; `match_score`/`match_explanation` included when match row
   exists, null when not; cursor pagination.
8. **`test_recruiter_resume_download.py`** — happy path returns blob bytes +
   correct Content-Type; recruiter at other employer → 404; applicant → 403
   `not_a_recruiter`; structured log `recruiter.resume-accessed` emitted
   (captured via `structlog.testing.capture_logs()`); when applicant has
   multiple resumes, the latest is returned.

## Settings

No new env vars in this slice. Existing `KPA_*` settings are sufficient.

## Out of scope

- Recruiter Flutter UI. All testing is API-only.
- Employer **invitations** (`employer_users.role='member'`) — schema-wired
  but no invite endpoint.
- Employer **verification** flow (admin endpoint that sets `verified_at`).
  Until P4 admin tooling, verification is a runbook SQL one-liner.
- Recruiter-side **status updates on an application** (shortlisted /
  rejected / hired). Deferred to P4 ("recruiter hiring stages").
- Cascade cleanup of `matches`/`applications`/`saved_jobs` when a job is
  soft-deleted. The `jobs.deleted_at` filter on read paths is sufficient.
- A persistent `audit_logs` table. The `recruiter.resume-accessed`
  structured log is the MVP audit trail; promote in P4.
- Applicant-side "who has seen my resume" view. Coupled to the P4 explicit-
  consent model.

## Risks / follow-ups

- **PII surface widens.** Recruiters can read applicant name + email +
  resume blob. Implicit consent ("applying = consenting to that one job's
  employer") is reasonable for MVP but DPDP-fragile. P4 must add an explicit
  consent record + an applicant-facing audit view.
- **`employer_name_taken` UX is hostile.** A real recruiter from "Acme Corp"
  who finds the name taken (typo'd teammate, prior attempt) has no path to
  join the existing row. Admin merge / invite path is documented for P4.
- **Unverified employer flood.** With no admin tooling and feed-surfacing
  on, anyone can create employers and surface jobs. Acceptable for internal
  demo; `employer_verified: bool` is the lever for a verified-only feed
  filter when admin lands.
- **Last-write-wins on PATCH.** Two recruiters editing the same job
  concurrently lose one set of edits silently. Acceptable for small teams;
  a `version` column can be added later additively.
