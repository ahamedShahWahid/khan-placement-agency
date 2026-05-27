# Applicant Profile View + Edit — Design

**Date:** 2026-05-27
**Status:** Approved (design); pending spec review
**Owner area:** `api/` (FastAPI) + `app/` (Flutter)

## Goal

Let an applicant see and edit their profile details — `full_name`, `locations`,
`notice_period_days`, `current_ctc`, `expected_ctc`, `years_experience` — from
the Flutter app, persisted via a new backend `PATCH` endpoint that re-triggers
matching when relevant fields change.

Out of scope (separate slices): resume management ("Resume: coming soon"),
notifications ("Notifications: coming soon"), recruiter/admin profiles.

## Background / current state

- `GET /v1/me` already returns the applicant block (`routes/me.py: ApplicantRead`):
  `{id, full_name, locations, notice_period_days, current_ctc, expected_ctc,
  years_experience}`. CTC/experience are `Numeric` → **serialized as JSON
  strings** by Pydantic v2 (see the DTO-contract audit memory).
- No applicant update endpoint exists. `IMPLEMENTATION_SPEC.md:90` references a
  `profile/ # applicant profile editor`; the P2.3 design defers
  "`PATCH /v1/me` for applicant profile updates that would trigger rescore" to a
  separate slice — this is that slice.
- The Flutter `MeDto.ApplicantSummaryDto` already parses these fields
  (post-audit): `currentCtc`/`expectedCtc`/`yearsExperience` are `String?`.
- The Profile screen currently shows only name + email + two "coming soon" rows.

### Matching ripple (verified against code)

- `canonicalize_profile` (the embedding text) uses resume-derived
  **skills/experience/education + full_name** only. It does **not** include
  locations, CTC, experience-years, or notice period.
- `scoring/structured.py` reads `applicant_locations`, `applicant_expected_ctc`,
  and experience for the `location`/`exp`/`ctc` components.
- Therefore: editing **locations / expected_ctc / years_experience** must trigger
  a **rescore** (`score_applicant`), NOT a re-embed. Dispatching `embed_applicant`
  would be wrong — its `canonicalized_text_hash` gate sees the canonical text
  unchanged and bails *before* its Txn3 rescore dispatch. `current_ctc` and
  `notice_period_days` are informational (no matching impact today).

## API design

### Endpoint: `PATCH /v1/applicants/me`

New module `api/src/kpa/routes/applicants.py`, `router = APIRouter(prefix="/v1/applicants/me")`.
(Chosen over the spec's offhand `PATCH /v1/me`: the applicant-scoped prefix
already exists — resumes live at `/v1/applicants/me/resumes` — so this is the
consistent home and can reuse the `_require_applicant` error ladder.)

Reuses the resumes error ladder, in order:
1. **401** — bearer/JWT/user re-fetch via `current_user`.
2. **403 `not_an_applicant`** — `_require_applicant` rejects recruiter/admin before any applicant read.
3. **500 `applicant_missing`** — defense in depth (sign-in provisions the row).
4. **422** — request-body validation (below).

`_require_applicant` is currently duplicated inline per route module (per
CLAUDE.md). Follow that convention: copy it into `applicants.py` rather than
extract, keeping each route module standalone.

### Request model `ProfileUpdate`

All fields optional; **true PATCH semantics** via Pydantic `model_fields_set`:
only keys present in the request are applied. An explicit `null` clears a
nullable column; an omitted key leaves it unchanged. `model_config =
ConfigDict(extra="forbid")` so unknown keys 422 (consistent with apply/withdraw).

| field | type | validation |
|---|---|---|
| `full_name` | `str` | `min_length=1, max_length=200` (not nullable — cannot clear) |
| `locations` | `list[str]` | ≤10 items; each `min_length=1, max_length=100`; not nullable (empty list allowed) |
| `notice_period_days` | `int \| None` | `ge=0, le=365` |
| `current_ctc` | `Decimal \| None` | `ge=0`; fits `Numeric(12,2)` (≤ 9_999_999_999.99) |
| `expected_ctc` | `Decimal \| None` | `ge=0`; fits `Numeric(12,2)` |
| `years_experience` | `Decimal \| None` | `ge=0, le=60`; fits `Numeric(4,1)` (one decimal place) |

Empty request body (`{}`) is a valid no-op → returns current `MeResponse`, no rescore.

### Handler behavior

1. Resolve applicant via `_require_applicant` (error ladder above).
2. For each key in `payload.model_fields_set`, set the column on the applicant row. Flush.
3. Build and return the updated `MeResponse` (same shape as `GET /v1/me`) so the
   client refreshes its cache from the response.
4. **Post-commit, fire-and-forget rescore**: `score_applicant.delay(applicant.id)`
   wrapped in broad `except Exception` + `_log.warning("score.dispatch-failed",
   exc_info=True)` — identical to the existing dispatch sites; a broker outage
   must not fail the save. MVP: dispatch on every non-empty save. **Follow-up**:
   gate dispatch on whether a matching-relevant field (`locations`,
   `expected_ctc`, `years_experience`) actually changed.

`score_applicant` no-ops safely when the applicant has no embedding yet (no
resume parsed) — matches require an embedding regardless.

### Response model

Return `MeResponse` (reuse from `routes/me.py`, import it). Status `200`.

### No migration

All columns already exist on `applicants`. No Alembic revision.

## App design

### Profile screen (`presentation/profile/profile_screen.dart`)

Replace the bare name/email block with a read-only details section + an **Edit**
action (AppBar `IconButton`/`TextButton`) → `context.go('/profile/edit')`.

Read-only rows (only shown when the applicant block is present):
- Locations (joined `, `; "—" if empty)
- Experience (`<n> yrs`; hidden if null)
- Notice period (`<n> days`; hidden if null)
- Current CTC / Expected CTC (formatted `₹` Indian grouping; hidden if null)

CTC formatting: a small helper formats the `String?` decimal as `₹12,00,000`
using `NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)`
(module-static `NumberFormat`, per the DateFormat hoisting lesson). Parse the
wire string with `double.tryParse`; show "—" / hide on null/unparseable.

### Edit screen (`presentation/profile/edit_profile_screen.dart`)

New route `/profile/edit`, nested under the **profile** tab branch in
`router.dart` (per the per-tab-stack pattern). Form:
- `full_name` — `TextFormField` (required, 1–200).
- `locations` — chip list with add-via-text-field + per-chip remove `✕`.
- `years_experience`, `notice_period_days`, `current_ctc`, `expected_ctc` —
  numeric `TextFormField`s (keyboard `TextInputType.numberWithOptions`).
- **Save** / **Cancel** in the AppBar. Save validates, calls the controller,
  shows a snackbar on error, pops on success.

Initial form values seed from the current `MeDto` (read from `meControllerProvider`).

### Data layer

- Extend `MeRepository` interface with `Future<MeDto> updateProfile(ProfileUpdateDto)`.
  Impl posts `PATCH /v1/applicants/me` via a new `MeApi.updateProfile`, maps
  `DioException` through `mapDioException`, returns `MeDto.fromJson(res.data!)`.
- New **request** DTO `ProfileUpdateDto` (`@JsonSerializable`, snake_case keys via
  `@JsonKey`): `full_name`, `locations`, `notice_period_days`, `current_ctc`,
  `expected_ctc`, `years_experience`. The edit form owns the full editable set, so
  the app sends **all six keys every save** — including explicit `null` for a
  field the user cleared (default `includeIfNull: true`), so clearing actually
  persists. CTC/experience sent as numbers (Pydantic coerces). (The backend's
  `model_fields_set` partial-update support still benefits non-form/API clients;
  the app simply always sends the complete set.)
- `ProfileEditController` (`@riverpod`) owns submit state (`AsyncValue<void>`):
  `submit(ProfileUpdateDto)` → `repo.updateProfile` → on success
  `ref.invalidate(meControllerProvider)`.

### Navigation

On save success: `ref.invalidate(meControllerProvider)` then `context.pop()` back
to the Profile screen, which re-reads the refreshed me. Do NOT invalidate the
feed (consistent with the "mutations don't touch the feed" rule); the rescore is
async server-side and the feed picks it up on its next load.

## Testing

### API (integration, real Postgres)
- `test_profile_update.py`:
  - happy path: partial update (e.g. `locations` + `expected_ctc`) → 200, DB row updated, other fields untouched.
  - `model_fields_set` semantics: omitted key unchanged; explicit `null` clears a nullable field.
  - validation 422s: `full_name` empty/too long, `locations` >10 / empty-string item, `notice_period_days` out of range, negative CTC, `years_experience` > 60, unknown key (`extra="forbid"`).
  - 403 `not_an_applicant` for a recruiter token.
  - rescore dispatch: patch `score_applicant.delay` and assert it's called with the applicant id on a matching-relevant change; assert NOT called for an empty body.

### App
- `me_repository_impl_test.dart`: add `updateProfile` — asserts `PATCH` path, request body carries the full editable set with snake_case keys (incl. explicit nulls for cleared fields; use `MockInterceptor.lastDataFor`), and response parses to `MeDto`.
- `profile_edit_controller_test.dart`: submit success invalidates me; submit error surfaces.
- `edit_profile_screen_test.dart` (widget): renders seeded values, add/remove a location chip, Save calls the repo with the edited values.
- Update `profile_screen_test.dart`: asserts the read-only detail rows render from a seeded `MeDto`.

## Risks / follow-ups

- **Rescore on every save** is wasteful at scale; follow-up to gate on changed
  matching fields.
- **CTC as free numeric text** — no currency-unit affordance (assumes annual ₹);
  acceptable for MVP.
- **No optimistic concurrency** — last write wins on the applicant row. Fine for
  single-user self-edit.
