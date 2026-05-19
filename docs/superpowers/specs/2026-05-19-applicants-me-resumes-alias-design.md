# `/v1/applicants/me/resumes` alias — design

**Date:** 2026-05-19
**Spec ref:** `IMPLEMENTATION_SPEC.md` §9.1 (identity / current_user), §10 (endpoint surface — already lists `/v1/applicants/me/resumes`).
**Status:** Approved by Ahamed. Ready for implementation plan.

Small follow-up that catches up to spec §10. P1.0 (resume upload) and P0 auth both shipped with the resume routes still taking `applicant_id` as a path parameter (the auth dep didn't exist when P1.0 was designed). This plan replaces that with `/v1/applicants/me/resumes` resolved through `current_user.id`.

## Why this slice

Both upload routes today read `applicant_id` from the URL path. Two problems:

1. **No authentication.** Any caller can post a resume to any applicant id by guessing/scraping UUIDs. The spec called this out as "lands with auth"; auth has now landed.
2. **API drift.** Spec §10 already documents `POST /v1/applicants/me/resumes`. Until this slice ships, that line is aspirational.

After this plan:
- The only way to upload a resume is via a Bearer access JWT.
- A recruiter or admin who hits the endpoint gets a clean 403 rather than a path that doesn't apply to them.
- The Flutter client's resume-upload screen calls `/me/resumes` with the access token it already holds — no UUID juggling.

## Decisions resolved during brainstorming

| # | Decision | Resolution |
|---|---|---|
| 1 | Branch base | From `main`, **after PR #6 (parse worker) merges.** Avoids a routes/resumes.py conflict. |
| 2 | Old path-param routes | **Removed outright.** They were placeholders for the pre-auth era; no internal callers depend on them. |
| 3 | Non-applicant role handling | **403 with `not_an_applicant` slug.** Explicit role check before any DB work. |

## Surface

Two routes, both nested under `/v1/applicants/me`:

```
POST   /v1/applicants/me/resumes              # multipart upload, Bearer required
GET    /v1/applicants/me/resumes/{resume_id}  # metadata, Bearer required
```

No path-param `applicant_id`. The old `POST /v1/applicants/{applicant_id}/resumes` and `GET /v1/applicants/{applicant_id}/resumes/{resume_id}` are deleted.

### Response shapes

Unchanged from current. `POST` returns `ResumeRead` (201). `GET` returns `ResumeRead` (200). The `applicant_id` field on `ResumeRead` is now derived server-side from the authenticated user, not echoed from the URL.

### Error model

| Status | Slug | Trigger |
|---|---|---|
| 401 | `missing_bearer_token` | No `Authorization: Bearer …` header |
| 401 | `invalid_access_token` | Access JWT signature / `iss` / `exp` / `iat` failures |
| 401 | `user_not_found` | Access JWT references a soft-deleted user |
| 403 | `not_an_applicant` | `user.role ∈ {recruiter, admin}` |
| 404 | `resume not found` | unchanged from current GET — uniform 404 across "unknown id" / "belongs to different applicant" |
| 413 | size exceeded | unchanged |
| 415 | bad content-type | unchanged |
| 500 | `applicant_missing` | `role=applicant` but no `applicants` row (data inconsistency — auth auto-provisioning should prevent this) |

The 500 case is theoretically unreachable: P0 auth's `_upsert_identity` creates an `applicants` row on every first sign-in. Guarding for it is defense in depth.

## Implementation

Single source file changes:

```
api/src/kpa/routes/resumes.py
```

Diff shape:

- Router prefix: `"/v1/applicants/{applicant_id}"` → `"/v1/applicants/me"`.
- Both handler signatures: drop `applicant_id: UUID`, add `user: User = Depends(current_user)`.
- Both handlers: call a new `_require_applicant(user, session) -> Applicant` helper at the top.
- Replace `applicant_id` references inside the handlers with `applicant.id`.

`_require_applicant` shape (new private helper, replaces the existing `_load_live_applicant`):

```python
async def _require_applicant(user: User, session: AsyncSession) -> Applicant:
    """Resolve the authenticated user to a live applicants row.

    Raises 403 not_an_applicant if user.role is not APPLICANT.
    Raises 500 applicant_missing if role=applicant but no row exists
    (theoretically unreachable; defense in depth against an auth
    auto-provisioning regression).
    """
    if user.role != UserRole.APPLICANT:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "not_an_applicant")
    applicant = (
        await session.execute(
            select(Applicant).where(
                Applicant.user_id == user.id,
                Applicant.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if applicant is None:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "applicant_missing")
    return applicant
```

The existing `_load_live_applicant(session, applicant_id)` helper is deleted — it has no remaining callers.

The GET handler's JOIN'd query (which collapses unknown-applicant / unknown-resume / mismatch into a uniform 404) stays; only the parameter source changes (use `applicant.id` resolved from `current_user` instead of the path parameter).

The dispatch line landed by PR #6 (`parse_resume.delay(str(resume.id))`) is unchanged — same call, same try/except wrapping. The PR conflict on `routes/resumes.py` resolves to "drop path-param, keep dispatch."

## Tests

`api/tests/integration/test_resumes_upload.py` — every test gets rewritten to:

1. Sign in via the `FakeGoogleIdTokenVerifier` (already wired into the integration conftest) to obtain a real access JWT.
2. Pass `Authorization: Bearer <token>` on every request.
3. Drop the `applicant_id` URL segment.

OR (simpler): override `app.dependency_overrides[current_user] = lambda: fake_applicant_user` directly. This is the same pattern the auth plan used for `test_me.py` integration tests.

Equivalent rewrite for `api/tests/integration/test_resumes_get.py` if it exists separately.

**New tests:**

- `test_upload_missing_bearer_returns_401` — POST without Authorization header → 401 `missing_bearer_token`.
- `test_upload_recruiter_role_returns_403` — POST with a recruiter user → 403 `not_an_applicant`.
- `test_get_resume_missing_bearer_returns_401` — same for GET.

**Coverage check:** the existing test suite's edge cases (415 wrong content-type, 413 oversized, 404 unknown resume id, 404 mismatched applicant) all remain — they just use the new `/me/resumes` path. The "mismatched applicant" case becomes "resume belongs to a different user" (rejected because the JOIN'd query filters by `applicant.user_id == user.id`).

Estimated test count: 8 rewrites + 3 new = 11 total (net +3).

## Out of scope

- **LIST endpoint** (`GET /me/resumes` returning all resumes) — separate plan once a UI needs it; will need cursor pagination per spec §10.
- **PATCH endpoint** (`PATCH /me/resumes/{id}` for the "mark uploaded → trigger parse" presigned-URL flow per spec §10) — lands with the S3 storage plan.
- **`require_role()` helper** — not introduced yet; the role check is inlined in `_require_applicant`. The helper lands when a second role-gated endpoint needs it.
- **Audit log entry** on resume upload — listed in spec §9.2 (DPDP audit_logs); separate plan.
- **Soft-delete cascade** when a user is soft-deleted (their resumes should also be inaccessible) — the GET's `Applicant.deleted_at.is_(None)` + `current_user`'s `user.deleted_at` check already cover this for the live-user case; orphaned resumes after admin deletion are a P4 admin-tooling concern.

## Spec deltas

None. §10 already documents the endpoint shape; this plan implements it.

## Branch + PR

- Branch: `feat/p1.2-applicants-me-resumes-alias`
- Base: `main` AFTER PR #6 (parse worker) merges
- Estimated: 1 implementation commit + 1 test-rewrite commit
- PR target: `main`
