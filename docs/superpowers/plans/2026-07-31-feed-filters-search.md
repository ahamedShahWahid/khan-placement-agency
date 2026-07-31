# Feed Filters & Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an applicant narrow their ranked match feed with location / experience-fit / min-CTC filters and a title+employer keyword search, per `docs/superpowers/specs/2026-07-31-feed-filters-search-design.md`.

**Architecture:** Extend `GET /v1/feed` with four optional query params that append WHERE predicates to the existing single feed statement; the opaque cursor gains an `f` filter-hash field so a cursor can never silently paginate under different filters. Flutter holds an ephemeral `FeedFilters` value object in a Riverpod notifier that `FeedController` watches — any change rebuilds the feed from page 1.

**Tech Stack:** FastAPI + SQLAlchemy 2 async (backend), pytest (`-m integration` needs local Postgres), Flutter + Riverpod 4 codegen + freezed + dio (app).

## Global Constraints

- Work on a feature branch: `scripts/new-feature.sh feed-filters-search` (never commit to `main`).
- All backend commands from **repo root**, `uv` only. All app commands from `app/`.
- CI-verbatim gates (run before claiming green):
  - `uv run ruff check core/src api/src worker/src tests`
  - `uv run ruff format --check core/src api/src worker/src tests`
  - `uv run mypy`
  - `uv run pytest -v -m "not integration and not eval"`
  - `uv run pytest -v -m integration`
  - app: `dart format --set-exit-if-changed lib test` · `flutter analyze` · `flutter test`
- New integration test additions go in files that already carry module-level `pytestmark = pytest.mark.integration`.
- No new error slugs: reuse `invalid_cursor` (400); validation failures are FastAPI 422s.
- No DB migration in this feature. No change to feed ordering `(total_score DESC, id DESC)`.
- Response shape of `/v1/feed` unchanged; **existing feed integration tests must pass unmodified**. (The two cursor *unit* tests in `tests/unit/test_feed_cursor.py` pin the decode tuple shape and are legitimately updated by Task 1.)
- After touching any `@freezed`/`@riverpod` Dart file: `dart run build_runner build --delete-conflicting-outputs` (from `app/`).
- Flutter widget tests use `ThemeData.light(useMaterial3: true)`, never `buildTheme()`.
- structlog only (backend); all handlers stay `async def`.

---

### Task 1: Backend — filter canonicalization hash + cursor `f` field

**Files:**
- Modify: `api/src/jobify_api/routes/feed.py` (cursor helpers at the top of the module, lines ~54–69)
- Test: `tests/unit/test_feed_cursor.py`

**Interfaces:**
- Produces: `filters_hash(q: str | None, locations: list[str] | None, min_years: int | None, min_ctc: Decimal | None) -> str | None` — returns `None` when every arg is absent/empty, else a 12-hex-char stable hash. Inputs are assumed **already normalized** (trimmed, empties dropped); the function only lowercases + sorts.
- Produces: `encode_cursor(score: Decimal, match_id: uuid.UUID, filters_hash: str | None = None) -> str` — omits the `f` payload key when hash is `None` (so unfiltered cursors are byte-compatible with pre-deploy cursors).
- Produces: `decode_cursor(cursor: str) -> tuple[Decimal, uuid.UUID, str | None]` — third element is the `f` value or `None`. **Breaking change to the 2-tuple**; Task 2 consumes the 3-tuple.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_feed_cursor.py`, and update the two existing tests that pin the decode tuple (`test_cursor_roundtrip` → expect `(score, mid, None)`; `test_cursor_score_precision_preserved` → unpack `decoded_score, _, _`):

```python
from decimal import Decimal

from jobify_api.routes.feed import decode_cursor, encode_cursor, filters_hash


def test_filters_hash_none_when_no_filters() -> None:
    assert filters_hash(None, None, None, None) is None
    assert filters_hash(None, [], None, None) is None


def test_filters_hash_stable_and_canonical() -> None:
    a = filters_hash("Flutter", ["Pune", "Remote"], 3, Decimal("500000"))
    b = filters_hash("flutter", ["remote", "PUNE"], 3, Decimal("500000"))
    assert a is not None
    assert a == b  # lowercased + sorted locations canonicalize
    assert len(a) == 12


def test_filters_hash_differs_per_filter_set() -> None:
    base = filters_hash("flutter", None, None, None)
    assert base != filters_hash("dart", None, None, None)
    assert base != filters_hash("flutter", ["Pune"], None, None)
    assert base != filters_hash("flutter", None, 3, None)
    assert base != filters_hash("flutter", None, None, Decimal("1"))


def test_cursor_roundtrip_with_filters_hash() -> None:
    score, mid = Decimal("0.8500"), uuid4()
    fhash = filters_hash("flutter", ["Pune"], None, None)
    assert decode_cursor(encode_cursor(score, mid, fhash)) == (score, mid, fhash)


def test_cursor_without_hash_decodes_none_f() -> None:
    score, mid = Decimal("0.8500"), uuid4()
    _, _, f = decode_cursor(encode_cursor(score, mid))
    assert f is None


def test_cursor_legacy_payload_without_f_key_decodes() -> None:
    # A pre-deploy cursor has no "f" key at all — must decode as f=None.
    import base64
    import json

    legacy = base64.urlsafe_b64encode(
        json.dumps({"score": "0.5", "match_id": str(uuid4())}).encode()
    ).decode("ascii")
    _, _, f = decode_cursor(legacy)
    assert f is None


def test_cursor_non_string_f_rejected() -> None:
    import base64
    import json

    bad = base64.urlsafe_b64encode(
        json.dumps({"score": "0.5", "match_id": str(uuid4()), "f": 7}).encode()
    ).decode("ascii")
    with pytest.raises(ValueError):
        decode_cursor(bad)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/unit/test_feed_cursor.py -v`
Expected: FAIL — `ImportError: cannot import name 'filters_hash'`.

- [ ] **Step 3: Implement in `routes/feed.py`**

Add `import hashlib` and `import json` to the module imports, then replace the cursor-helper section:

```python
def filters_hash(
    q: str | None,
    locations: list[str] | None,
    min_years: int | None,
    min_ctc: Decimal | None,
) -> str | None:
    """Short stable hash of the canonicalized filter set; None = no filters.

    Inputs must already be normalized (trimmed, empties dropped) — this
    function only canonicalizes case + location order.
    """
    if q is None and not locations and min_years is None and min_ctc is None:
        return None
    canon = json.dumps(
        {
            "q": q.lower() if q is not None else None,
            "loc": sorted(loc.lower() for loc in locations) if locations else None,
            "years": min_years,
            "ctc": str(min_ctc) if min_ctc is not None else None,
        },
        sort_keys=True,
    )
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()[:12]


def encode_cursor(
    score: Decimal, match_id: uuid.UUID, filters_hash: str | None = None
) -> str:
    """Pack (score, match_id[, filter-set hash]) into an opaque base64 string."""
    payload: dict[str, str] = {"score": str(score), "match_id": str(match_id)}
    if filters_hash is not None:
        payload["f"] = filters_hash
    return _encode_cursor_payload(payload)


def decode_cursor(cursor: str) -> tuple[Decimal, uuid.UUID, str | None]:
    """Decode an opaque cursor. Raises ValueError on any malformed input."""
    payload = _decode_cursor_payload(cursor)
    try:
        f = payload.get("f")
        if f is not None and not isinstance(f, str):
            raise TypeError("f is not a string")
        return Decimal(payload["score"]), uuid.UUID(payload["match_id"]), f
    except (ValueError, KeyError, TypeError, ArithmeticError) as exc:
        # ArithmeticError covers decimal.InvalidOperation on a garbage score.
        raise ValueError(f"invalid_cursor: {exc}") from exc
```

Then fix the two call sites inside `get_feed` so the module still compiles: the decode call becomes `cursor_score, cursor_mid, _cursor_f = decode_cursor(cursor)` (the `f` check itself lands in Task 2), and the encode call stays `encode_cursor(last_match.total_score, last_match.id)` for now.

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/unit/test_feed_cursor.py -v`
Expected: all PASS (including the two updated pre-existing tests).

- [ ] **Step 5: Quick regression + commit**

Run: `uv run pytest -m "not integration and not eval" -q` and `uv run mypy`
Expected: PASS.

```bash
git add api/src/jobify_api/routes/feed.py tests/unit/test_feed_cursor.py
git commit -m "feat(feed): filter-set hash + cursor f field (cursor binds to its filters)"
```

---

### Task 2: Backend — `/v1/feed` filter params, WHERE predicates, cursor-hash enforcement

**Files:**
- Modify: `api/src/jobify_api/routes/feed.py` (`get_feed`, lines ~72–169)
- Test: `tests/integration/test_feed.py` (append; module already has `pytestmark = pytest.mark.integration`)

**Interfaces:**
- Consumes: `filters_hash` / `encode_cursor` / `decode_cursor` from Task 1 (exact signatures above).
- Produces: `GET /v1/feed` accepts optional `q` (str ≤100), repeatable `location` (each stripped, 1–100 chars), `min_years` (int ≥0), `min_ctc` (Decimal ≥0, absolute ₹). Filter/cursor mismatch → `400 invalid_cursor`.

- [ ] **Step 1: Extend the job/employer test helper**

In `tests/integration/test_feed.py`, widen `_make_job_and_employer` (keep existing defaults so current tests are untouched):

```python
async def _make_job_and_employer(
    session: AsyncSession,
    *,
    title: str = "Engineer",
    employer_name: str = "Acme",
    status_value: JobStatus = JobStatus.OPEN,
    locations: list[str] | None = None,
    min_exp_years: int = 1,
    max_exp_years: int = 5,
    ctc_max: float | None = None,
) -> tuple[Job, Employer]:
    employer = Employer(name=employer_name, name_norm=employer_name.lower())
    session.add(employer)
    await session.flush()
    job = Job(
        employer_id=employer.id,
        title=title,
        description="x",
        locations=locations if locations is not None else ["Bangalore"],
        min_exp_years=min_exp_years,
        max_exp_years=max_exp_years,
        ctc_max=ctc_max,
        status=status_value,
    )
    session.add(job)
    await session.flush()
    return job, employer
```

- [ ] **Step 2: Write the failing integration tests**

Append to `tests/integration/test_feed.py`:

```python
async def _seed_three(
    session: AsyncSession, email: str
) -> tuple[User, Applicant]:
    """Three surfaced matches: Flutter/Pune, Backend/Bangalore, Data/Remote."""
    user, applicant = await _make_applicant(session, email=email)
    j1, _ = await _make_job_and_employer(
        session, title="Flutter Developer", employer_name="Acme Mobile",
        locations=["Pune"], min_exp_years=2, max_exp_years=5,
        ctc_max=1_200_000,
    )
    j2, _ = await _make_job_and_employer(
        session, title="Backend Engineer", employer_name="Beta Systems",
        locations=["Bangalore"], min_exp_years=0, max_exp_years=2,
        ctc_max=600_000,
    )
    j3, _ = await _make_job_and_employer(
        session, title="Data Analyst", employer_name="Gamma Insights",
        locations=["Remote"], min_exp_years=1, max_exp_years=8,
        ctc_max=None,
    )
    await _make_match(session, applicant_id=applicant.id, job_id=j1.id, total_score=0.9)
    await _make_match(session, applicant_id=applicant.id, job_id=j2.id, total_score=0.8)
    await _make_match(session, applicant_id=applicant.id, job_id=j3.id, total_score=0.7)
    await session.commit()
    return user, applicant


@pytest.mark.integration
async def test_feed_q_matches_title_and_employer_case_insensitive(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "q1@example.com")
    h = _token_headers(user)

    resp = await async_client.get("/v1/feed", params={"q": "flutter"}, headers=h)
    assert [i["job"]["title"] for i in resp.json()["items"]] == ["Flutter Developer"]

    resp = await async_client.get("/v1/feed", params={"q": "beta"}, headers=h)
    assert [i["job"]["title"] for i in resp.json()["items"]] == ["Backend Engineer"]


@pytest.mark.integration
async def test_feed_q_whitespace_treated_as_absent(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "q2@example.com")
    resp = await async_client.get(
        "/v1/feed", params={"q": "   "}, headers=_token_headers(user)
    )
    assert len(resp.json()["items"]) == 3


@pytest.mark.integration
async def test_feed_q_ilike_metacharacters_literal(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, applicant = await _make_applicant(session, email="q3@example.com")
    j1, _ = await _make_job_and_employer(session, title="100% Remote QA")
    j2, _ = await _make_job_and_employer(session, title="100x Growth QA", employer_name="Bx")
    await _make_match(session, applicant_id=applicant.id, job_id=j1.id, total_score=0.9)
    await _make_match(session, applicant_id=applicant.id, job_id=j2.id, total_score=0.8)
    await session.commit()

    resp = await async_client.get(
        "/v1/feed", params={"q": "100%"}, headers=_token_headers(user)
    )
    assert [i["job"]["title"] for i in resp.json()["items"]] == ["100% Remote QA"]


@pytest.mark.integration
async def test_feed_location_or_semantics_case_insensitive(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "loc@example.com")
    resp = await async_client.get(
        "/v1/feed",
        params=[("location", "pune"), ("location", "REMOTE")],
        headers=_token_headers(user),
    )
    titles = [i["job"]["title"] for i in resp.json()["items"]]
    assert titles == ["Flutter Developer", "Data Analyst"]  # score order kept


@pytest.mark.integration
async def test_feed_min_years_fit_band(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "yrs@example.com")
    # 6 years: fits only Data Analyst (1–8); Flutter is 2–5, Backend 0–2.
    resp = await async_client.get(
        "/v1/feed", params={"min_years": 6}, headers=_token_headers(user)
    )
    assert [i["job"]["title"] for i in resp.json()["items"]] == ["Data Analyst"]


@pytest.mark.integration
async def test_feed_min_ctc_keeps_undisclosed(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "ctc@example.com")
    # 10L: drops Backend (6L max), keeps Flutter (12L) AND Data (undisclosed).
    resp = await async_client.get(
        "/v1/feed", params={"min_ctc": 1_000_000}, headers=_token_headers(user)
    )
    titles = [i["job"]["title"] for i in resp.json()["items"]]
    assert titles == ["Flutter Developer", "Data Analyst"]


@pytest.mark.integration
async def test_feed_filters_compose_with_and(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "and@example.com")
    resp = await async_client.get(
        "/v1/feed",
        params={"q": "developer", "location": "Pune", "min_years": 3},
        headers=_token_headers(user),
    )
    assert [i["job"]["title"] for i in resp.json()["items"]] == ["Flutter Developer"]


@pytest.mark.integration
async def test_feed_filtered_pagination_and_cursor_binding(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "page@example.com")
    h = _token_headers(user)

    # Filter matching 2 jobs (Flutter + Data via min_ctc), page size 1.
    p1 = await async_client.get(
        "/v1/feed", params={"min_ctc": 1_000_000, "limit": 1}, headers=h
    )
    body = p1.json()
    assert [i["job"]["title"] for i in body["items"]] == ["Flutter Developer"]
    cur = body["next_cursor"]
    assert cur is not None

    # Same filters + cursor → page 2.
    p2 = await async_client.get(
        "/v1/feed", params={"min_ctc": 1_000_000, "limit": 1, "cursor": cur}, headers=h
    )
    assert [i["job"]["title"] for i in p2.json()["items"]] == ["Data Analyst"]

    # Same cursor WITHOUT the filter → 400 invalid_cursor.
    p3 = await async_client.get("/v1/feed", params={"cursor": cur}, headers=h)
    assert p3.status_code == 400

    # Same cursor with a DIFFERENT filter value → 400.
    p4 = await async_client.get(
        "/v1/feed", params={"min_ctc": 999, "cursor": cur}, headers=h
    )
    assert p4.status_code == 400


@pytest.mark.integration
async def test_feed_unfiltered_cursor_rejected_once_filters_added(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _seed_three(session, "legacy@example.com")
    h = _token_headers(user)
    p1 = await async_client.get("/v1/feed", params={"limit": 1}, headers=h)
    cur = p1.json()["next_cursor"]
    assert cur is not None  # f-less cursor (also the pre-deploy legacy shape)

    ok = await async_client.get("/v1/feed", params={"cursor": cur}, headers=h)
    assert ok.status_code == 200  # still valid unfiltered

    bad = await async_client.get(
        "/v1/feed", params={"cursor": cur, "q": "flutter"}, headers=h
    )
    assert bad.status_code == 400


@pytest.mark.integration
async def test_feed_filter_validation_422(
    session: AsyncSession, async_client: AsyncClient
) -> None:
    user, _ = await _make_applicant(session, email="v@example.com")
    await session.commit()
    h = _token_headers(user)
    assert (await async_client.get("/v1/feed", params={"min_years": -1}, headers=h)).status_code == 422
    assert (await async_client.get("/v1/feed", params={"min_ctc": -5}, headers=h)).status_code == 422
    assert (await async_client.get("/v1/feed", params={"q": "x" * 101}, headers=h)).status_code == 422
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `uv run pytest tests/integration/test_feed.py -v -k "q_matches or whitespace or metacharacters or location_or or min_years or min_ctc or compose or cursor_binding or legacy or validation"`
Expected: FAIL — unfiltered results returned / no 400s (params silently ignored today).

- [ ] **Step 4: Implement in `get_feed`**

Add imports: `from typing import Annotated`, `from pydantic import StringConstraints`, and extend the existing `sqlalchemy` import line with `exists, func`.

New module-level helper next to the cursor helpers:

```python
_LIKE_ESCAPE = "\\"


def _escape_like(term: str) -> str:
    """Escape ILIKE metacharacters so user input matches literally."""
    return term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


_LocationItem = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)
]
```

Widen the handler signature (after `cursor`):

```python
    q: str | None = Query(None, max_length=100),
    location: list[_LocationItem] | None = Query(None),
    min_years: int | None = Query(None, ge=0),
    min_ctc: Decimal | None = Query(None, ge=0),
```

Immediately after `applicant = await _require_applicant(user, session)`:

```python
    # Normalize BEFORE hashing so the cursor hash sees canonical values.
    q_norm = (q or "").strip() or None
    locations = list(location or [])
    fhash = filters_hash(q_norm, locations, min_years, min_ctc)
```

Replace the cursor-decode block so the hash is enforced:

```python
    cursor_score: Decimal | None = None
    cursor_mid: uuid.UUID | None = None
    if cursor is not None:
        try:
            cursor_score, cursor_mid, cursor_f = decode_cursor(cursor)
        except ValueError:
            raise HTTPException(status_code=400, detail="invalid_cursor") from None
        if cursor_f != fhash:
            # A cursor minted under a different filter set can't be resumed —
            # silently mixing pages would be worse than a clean 400.
            raise HTTPException(status_code=400, detail="invalid_cursor")
```

After the existing `stmt = (...)` construction, append the filter predicates:

```python
    if q_norm is not None:
        pat = f"%{_escape_like(q_norm)}%"
        stmt = stmt.where(
            or_(
                Job.title.ilike(pat, escape=_LIKE_ESCAPE),
                Employer.name.ilike(pat, escape=_LIKE_ESCAPE),
            )
        )
    if locations:
        loc_el = func.unnest(Job.locations).table_valued("value", joins_implicitly=True)
        stmt = stmt.where(
            exists(
                select(literal(1))
                .select_from(loc_el)
                .where(func.lower(loc_el.c.value).in_([loc.lower() for loc in locations]))
            )
        )
    if min_years is not None:
        stmt = stmt.where(Job.min_exp_years <= min_years, Job.max_exp_years >= min_years)
    if min_ctc is not None:
        stmt = stmt.where(or_(Job.ctc_max.is_(None), Job.ctc_max >= min_ctc))
```

Finally, mint the next cursor bound to the filter set:

```python
        next_cursor = encode_cursor(last_match.total_score, last_match.id, fhash)
```

Update the module docstring's cursor sentence to mention the optional `f` filter-hash field.

- [ ] **Step 5: Run tests to verify they pass**

Run: `uv run pytest tests/integration/test_feed.py -v`
Expected: ALL pass — new tests AND every pre-existing feed test (proves the no-params path untouched).

- [ ] **Step 6: Commit**

```bash
git add api/src/jobify_api/routes/feed.py tests/integration/test_feed.py
git commit -m "feat(feed): location/experience/CTC filters + title+employer keyword search"
```

---

### Task 3: Backend — OpenAPI snapshot, full gate, api/CLAUDE.md note

**Files:**
- Modify: `tests/unit/openapi_snapshot.json` (regenerated)
- Modify: `api/CLAUDE.md` (Feed + job detail section)

**Interfaces:**
- Consumes: the widened `/v1/feed` signature from Task 2.

- [ ] **Step 1: Regenerate the snapshot and review the diff**

Run: `JOBIFY_UPDATE_OPENAPI_SNAPSHOT=1 uv run pytest tests/unit/test_openapi_contract.py`
Then: `git diff tests/unit/openapi_snapshot.json`
Expected diff: ONLY four new optional query params on `GET /v1/feed` (`q`, `location`, `min_years`, `min_ctc`). Any other delta = a bug in Task 2 — stop and fix.

- [ ] **Step 2: Append the invariant to `api/CLAUDE.md`**

Add one bullet to the "Feed + job detail" section:

```markdown
- **Feed filters (spec `2026-07-31-feed-filters-search-design.md`):** optional `q`/`location`(repeatable)/`min_years`/`min_ctc` narrow the same statement — never the ordering. `min_ctc` keeps `ctc_max IS NULL` jobs visible (undisclosed pay ≠ low pay). The cursor payload's `f` field is the canonicalized filter-set hash; mismatch with the request's params → `400 invalid_cursor` (an f-less cursor is the "no filters" case, which also keeps pre-deploy cursors valid). Normalize params (trim, drop empties) BEFORE `filters_hash` — hashing raw input would make equal filter sets produce different hashes.
```

- [ ] **Step 3: Run the full backend gate (CI-verbatim)**

Run all five backend commands from Global Constraints.
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/openapi_snapshot.json api/CLAUDE.md
git commit -m "chore(feed): pin filter query params in OpenAPI snapshot + CLAUDE.md invariant"
```

---

### Task 4: App — `FeedFilters` value object + data-layer plumbing

**Files:**
- Create: `app/lib/data/feed/feed_filters.dart`
- Modify: `app/lib/data/feed/feed_api.dart`
- Modify: `app/lib/data/feed/feed_repository.dart`
- Modify: `app/lib/data/feed/feed_repository_impl.dart`
- Modify: `app/test/helpers/fake_repositories.dart` (`FakeFeedRepository`)
- Test: `app/test/unit/data/feed/feed_filters_test.dart`

**Interfaces:**
- Produces: `FeedFilters` (freezed): `{String? query, List<String> locations = const [], int? minYears, double? minCtc}` with `bool get isEmpty` and `Map<String, dynamic> toQueryParameters()`. `minCtc` is **absolute ₹** (UI converts from lakhs).
- Produces: `FeedRepository.fetchPage({String? cursor, int limit = 20, FeedFilters? filters})` — Tasks 5–6 consume this exact signature.

- [ ] **Step 1: Write the failing test**

`app/test/unit/data/feed/feed_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';

void main() {
  test('isEmpty: default and whitespace-only query are empty', () {
    expect(const FeedFilters().isEmpty, isTrue);
    expect(const FeedFilters(query: '   ').isEmpty, isTrue);
    expect(const FeedFilters(query: 'x').isEmpty, isFalse);
    expect(const FeedFilters(locations: ['Pune']).isEmpty, isFalse);
    expect(const FeedFilters(minYears: 0).isEmpty, isFalse);
    expect(const FeedFilters(minCtc: 500000).isEmpty, isFalse);
  });

  test('toQueryParameters emits only set keys, trims query', () {
    expect(const FeedFilters().toQueryParameters(), isEmpty);
    expect(
      const FeedFilters(
        query: ' flutter ',
        locations: ['Pune', 'Remote'],
        minYears: 3,
        minCtc: 500000,
      ).toQueryParameters(),
      {
        'q': 'flutter',
        'location': ['Pune', 'Remote'],
        'min_years': 3,
        'min_ctc': 500000.0,
      },
    );
  });

  test('value equality', () {
    expect(const FeedFilters(query: 'a', locations: ['P']),
        const FeedFilters(query: 'a', locations: ['P']));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (from `app/`): `flutter test test/unit/data/feed/feed_filters_test.dart`
Expected: FAIL — `feed_filters.dart` does not exist.

- [ ] **Step 3: Implement**

`app/lib/data/feed/feed_filters.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_filters.freezed.dart';

/// Ephemeral applicant feed filters — query params only, never persisted.
/// [minCtc] is absolute rupees (the UI converts from lakhs).
@freezed
abstract class FeedFilters with _$FeedFilters {
  const FeedFilters._();

  const factory FeedFilters({
    String? query,
    @Default(<String>[]) List<String> locations,
    int? minYears,
    double? minCtc,
  }) = _FeedFilters;

  bool get isEmpty =>
      (query == null || query!.trim().isEmpty) &&
      locations.isEmpty &&
      minYears == null &&
      minCtc == null;

  /// Dio's default ListFormat.multi serializes the list value as repeated
  /// `location=` params, matching the backend's `list[str]` Query.
  Map<String, dynamic> toQueryParameters() => {
        if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
        if (locations.isNotEmpty) 'location': locations,
        if (minYears != null) 'min_years': minYears,
        if (minCtc != null) 'min_ctc': minCtc,
      };
}
```

`feed_api.dart` — widen `getFeed`:

```dart
  Future<FeedPageDto> getFeed(
      {String? cursor, int limit = 20, FeedFilters? filters}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/feed',
      queryParameters: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        ...?filters?.toQueryParameters(),
      },
    );
    return FeedPageDto.fromJson(res.data!);
  }
```

`feed_repository.dart`:

```dart
abstract interface class FeedRepository {
  Future<FeedPageDto> fetchPage(
      {String? cursor, int limit = 20, FeedFilters? filters});
}
```

`feed_repository_impl.dart` — pass-through:

```dart
  @override
  Future<FeedPageDto> fetchPage(
      {String? cursor, int limit = 20, FeedFilters? filters}) async {
    try {
      return await _api.getFeed(cursor: cursor, limit: limit, filters: filters);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
```

`fake_repositories.dart` — widen `FakeFeedRepository.fetchPage` with the same signature (record `filters` into a public `FeedFilters? lastFilters` field for widget tests), and add the import. Add the `filters` param to `_FakeFeedRepo` in `app/test/unit/presentation/feed/feed_controller_test.dart` too (it implements the interface).

Then: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/data/feed/`
Expected: PASS (new test + existing feed data tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/data/feed/ app/test/
git commit -m "feat(app): FeedFilters value object + feed data-layer filter plumbing"
```

---

### Task 5: App — filters state provider + FeedController wiring

**Files:**
- Create: `app/lib/presentation/feed/feed_filters_provider.dart`
- Modify: `app/lib/presentation/feed/feed_controller.dart`
- Test: `app/test/unit/presentation/feed/feed_filters_provider_test.dart`
- Test: `app/test/unit/presentation/feed/feed_controller_test.dart` (extend)

**Interfaces:**
- Consumes: `FeedFilters`, `FeedRepository.fetchPage(filters:)` from Task 4.
- Produces: `feedFiltersControllerProvider` — `Notifier<FeedFilters>` with `void set(FeedFilters)` and `void clear()`. Auto-dispose on purpose: it dies with the applicant shell (sign-out resets filters for free); it stays alive during the session because `FeedController` (watched by the kept-alive `FeedScreen`) watches it.

- [ ] **Step 1: Write the failing tests**

`app/test/unit/presentation/feed/feed_filters_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';

void main() {
  test('defaults empty; set + clear round-trip', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    // Keep the autoDispose provider alive for the test's duration.
    final sub = c.listen(feedFiltersControllerProvider, (_, __) {});
    addTearDown(sub.close);

    expect(c.read(feedFiltersControllerProvider).isEmpty, isTrue);
    c.read(feedFiltersControllerProvider.notifier).set(
        const FeedFilters(query: 'flutter', minYears: 3));
    expect(c.read(feedFiltersControllerProvider).query, 'flutter');
    c.read(feedFiltersControllerProvider.notifier).clear();
    expect(c.read(feedFiltersControllerProvider).isEmpty, isTrue);
  });
}
```

Extend `feed_controller_test.dart` — first widen `_FakeFeedRepo` to record calls:

```dart
class _FakeFeedRepo implements FeedRepository {
  _FakeFeedRepo(this.pages);
  final List<FeedPageDto> pages;
  int call = 0;
  final List<FeedFilters?> receivedFilters = [];
  final List<String?> receivedCursors = [];
  @override
  Future<FeedPageDto> fetchPage(
      {String? cursor, int limit = 20, FeedFilters? filters}) async {
    receivedFilters.add(filters);
    receivedCursors.add(cursor);
    return pages[call++];
  }
}
```

New tests:

```dart
  test('filter change rebuilds feed from page 1 with filters applied',
      () async {
    final repo = _FakeFeedRepo([
      FeedPageDto(items: [_item('j1')], nextCursor: 'c1'),
      FeedPageDto(items: [_item('j2')]),
    ]);
    final c = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(feedControllerProvider, (_, __) {});
    addTearDown(sub.close);

    await c.read(feedControllerProvider.future);
    expect(repo.receivedFilters, [null]); // empty filters sent as null

    c.read(feedFiltersControllerProvider.notifier).set(
        const FeedFilters(locations: ['Pune']));
    final s = await c.read(feedControllerProvider.future);

    expect(s.items.single.job.id, 'j2');
    expect(repo.receivedCursors.last, isNull); // reset to page 1
    expect(repo.receivedFilters.last,
        const FeedFilters(locations: ['Pune']));
  });

  test('loadMore carries the active filters', () async {
    final repo = _FakeFeedRepo([
      FeedPageDto(items: [_item('j1')], nextCursor: 'c1'),
      FeedPageDto(items: [_item('j2')]),
    ]);
    final c = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(feedControllerProvider, (_, __) {});
    addTearDown(sub.close);

    c.read(feedFiltersControllerProvider.notifier).set(
        const FeedFilters(query: 'x'));
    await c.read(feedControllerProvider.future);
    await c.read(feedControllerProvider.notifier).loadMore();

    expect(repo.receivedCursors.last, 'c1');
    expect(repo.receivedFilters.last, const FeedFilters(query: 'x'));
  });
```

Add the needed imports (`feed_filters.dart`, `feed_filters_provider.dart`).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/unit/presentation/feed/`
Expected: FAIL — `feed_filters_provider.dart` missing / `fetchPage` filters unused.

- [ ] **Step 3: Implement**

`app/lib/presentation/feed/feed_filters_provider.dart`:

```dart
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_filters_provider.g.dart';

/// Ephemeral, session-scoped filter state. Deliberately autoDispose: it lives
/// exactly as long as the applicant shell (FeedScreen watches FeedController,
/// which watches this) and resets on sign-out for free.
@riverpod
class FeedFiltersController extends _$FeedFiltersController {
  @override
  FeedFilters build() => const FeedFilters();

  void set(FeedFilters filters) => state = filters;

  void clear() => state = const FeedFilters();
}
```

`feed_controller.dart` — `build()` watches filters (a change invalidates the feed, which IS the cursor reset), `loadMore` reads them:

```dart
  @override
  Future<FeedState> build() async {
    final filters = ref.watch(feedFiltersControllerProvider);
    final page = await ref
        .read(feedRepositoryProvider)
        .fetchPage(filters: filters.isEmpty ? null : filters);
    return PagedState(
      items: page.items,
      cursor: page.nextCursor,
      hasMore: page.nextCursor != null,
    );
  }

  Future<void> loadMore() => loadNextPage<FeedItemDto>(
        currentState: state,
        fetch: ({String? cursor}) async {
          final filters = ref.read(feedFiltersControllerProvider);
          final page = await ref.read(feedRepositoryProvider).fetchPage(
              cursor: cursor,
              filters: filters.isEmpty ? null : filters);
          return PagedState(
            items: page.items,
            cursor: page.nextCursor,
            hasMore: page.nextCursor != null,
          );
        },
        setState: (s) => state = s,
      );
```

Add imports; run `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/presentation/feed/`
Expected: PASS (new + all pre-existing controller tests).

- [ ] **Step 5: Commit**

```bash
git add app/lib/presentation/feed/ app/test/unit/presentation/feed/
git commit -m "feat(app): feed filters provider + FeedController filter wiring"
```

---

### Task 6: App — filter bar UI, bottom sheet, filtered empty state

**Files:**
- Create: `app/lib/presentation/feed/feed_filter_bar.dart`
- Create: `app/lib/presentation/feed/feed_filter_sheet.dart`
- Modify: `app/lib/presentation/feed/feed_screen.dart`
- Test: `app/test/widget/feed_filter_test.dart`

**Interfaces:**
- Consumes: `feedFiltersControllerProvider` (`set`/`clear`), `FeedFilters` (Tasks 4–5).
- Produces: UI only — no new public API.

- [ ] **Step 1: Write the failing widget tests**

`app/test/widget/feed_filter_test.dart` (mirror the harness of `app/test/widget/feed_screen_test.dart` — same ProviderScope overrides with `FakeFeedRepository` and `ThemeData.light(useMaterial3: true)`; if that file wraps in a helper `pumpFeedScreen`, reuse it):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filter_bar.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('search field debounces then sets query filter', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    })));

    await tester.enterText(find.byType(TextField), 'flutter');
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(feedFiltersControllerProvider).query, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(feedFiltersControllerProvider).query, 'flutter');
  });

  testWidgets('active filters render chips; clearing a chip removes it',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(_wrap(Consumer(builder: (context, ref, _) {
      container = ProviderScope.containerOf(context);
      return const FeedFilterBar();
    })));
    container.read(feedFiltersControllerProvider.notifier).set(
        const FeedFilters(locations: ['Pune'], minYears: 3));
    await tester.pump();

    expect(find.text('Pune'), findsOneWidget);
    expect(find.text('3 yrs'), findsOneWidget);

    // Invoke onDeleted directly — the default delete-icon glyph differs
    // between Material versions, so tapping by icon is fragile.
    tester
        .widget<InputChip>(find.widgetWithText(InputChip, 'Pune'))
        .onDeleted!();
    await tester.pump();
    expect(container.read(feedFiltersControllerProvider).locations, isEmpty);
    expect(container.read(feedFiltersControllerProvider).minYears, 3);
  });
}
```

Plus one screen-level test appended to the same file, asserting the filtered empty state (override `feedRepositoryProvider` with a `FakeFeedRepository(items: [])`, set a filter, pump `FeedScreen`, expect `find.text('Nothing matches your filters')` and a `Clear filters` button whose tap empties `feedFiltersControllerProvider`). Copy the exact scaffold/override boilerplate from `feed_screen_test.dart`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/widget/feed_filter_test.dart`
Expected: FAIL — `FeedFilterBar` does not exist.

- [ ] **Step 3: Implement `FeedFilterBar`**

`app/lib/presentation/feed/feed_filter_bar.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filter_sheet.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

/// Search field + filter button + active-filter chips under the feed summary.
class FeedFilterBar extends ConsumerStatefulWidget {
  const FeedFilterBar({super.key});

  @override
  ConsumerState<FeedFilterBar> createState() => _FeedFilterBarState();
}

class _FeedFilterBarState extends ConsumerState<FeedFilterBar> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final current = ref.read(feedFiltersControllerProvider);
      ref
          .read(feedFiltersControllerProvider.notifier)
          .set(current.copyWith(query: value.trim().isEmpty ? null : value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(feedFiltersControllerProvider);
    final notifier = ref.read(feedFiltersControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search title or company',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: JobifySpacing.sm),
            IconButton(
              tooltip: 'Filters',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const FeedFilterSheet(),
              ),
              icon: Icon(
                Icons.tune,
                color: filters.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        if (!filters.isEmpty) ...[
          const SizedBox(height: JobifySpacing.sm),
          Wrap(
            spacing: JobifySpacing.sm,
            runSpacing: JobifySpacing.sm,
            children: [
              for (final loc in filters.locations)
                InputChip(
                  label: Text(loc),
                  onDeleted: () => notifier.set(filters.copyWith(
                    locations: [
                      for (final l in filters.locations)
                        if (l != loc) l,
                    ],
                  )),
                ),
              if (filters.minYears != null)
                InputChip(
                  label: Text('${filters.minYears} yrs'),
                  onDeleted: () =>
                      notifier.set(filters.copyWith(minYears: null)),
                ),
              if (filters.minCtc != null)
                InputChip(
                  label: Text('≥ ₹${(filters.minCtc! / 100000).toStringAsFixed(filters.minCtc! % 100000 == 0 ? 0 : 1)}L'),
                  onDeleted: () => notifier.set(filters.copyWith(minCtc: null)),
                ),
              ActionChip(
                label: const Text('Clear all'),
                onPressed: () {
                  _searchController.clear();
                  notifier.clear();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 4: Implement `FeedFilterSheet`**

`app/lib/presentation/feed/feed_filter_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobify_app/data/feed/feed_filters.dart';
import 'package:jobify_app/presentation/feed/feed_filters_provider.dart';
import 'package:jobify_app/presentation/theme/jobify_spacing.dart';

const _presetCities = [
  'Bangalore',
  'Mumbai',
  'Delhi NCR',
  'Hyderabad',
  'Chennai',
  'Pune',
  'Remote',
];

/// Bottom sheet editing location / experience / min-CTC. Local draft state;
/// nothing hits the provider until Apply.
class FeedFilterSheet extends ConsumerStatefulWidget {
  const FeedFilterSheet({super.key});

  @override
  ConsumerState<FeedFilterSheet> createState() => _FeedFilterSheetState();
}

class _FeedFilterSheetState extends ConsumerState<FeedFilterSheet> {
  late List<String> _locations;
  int? _minYears;
  late final TextEditingController _ctcLakhController;
  final _customCityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final f = ref.read(feedFiltersControllerProvider);
    _locations = [...f.locations];
    _minYears = f.minYears;
    _ctcLakhController = TextEditingController(
      text: f.minCtc == null ? '' : (f.minCtc! / 100000).toString(),
    );
  }

  @override
  void dispose() {
    _ctcLakhController.dispose();
    _customCityController.dispose();
    super.dispose();
  }

  void _toggleCity(String city, bool selected) {
    setState(() {
      if (selected) {
        if (!_locations.contains(city)) _locations.add(city);
      } else {
        _locations.remove(city);
      }
    });
  }

  void _apply() {
    final current = ref.read(feedFiltersControllerProvider);
    final lakh = double.tryParse(_ctcLakhController.text.trim());
    ref.read(feedFiltersControllerProvider.notifier).set(
          FeedFilters(
            query: current.query,
            locations: _locations,
            minYears: _minYears,
            minCtc: lakh == null || lakh <= 0 ? null : lakh * 100000,
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: JobifySpacing.lg,
        right: JobifySpacing.lg,
        top: JobifySpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + JobifySpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter matches', style: theme.textTheme.titleMedium),
          const SizedBox(height: JobifySpacing.lg),
          Text('Location', style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          Wrap(
            spacing: JobifySpacing.sm,
            runSpacing: JobifySpacing.sm,
            children: [
              for (final city in {..._presetCities, ..._locations})
                FilterChip(
                  label: Text(city),
                  selected: _locations.contains(city),
                  onSelected: (sel) => _toggleCity(city, sel),
                ),
            ],
          ),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _customCityController,
            decoration: const InputDecoration(
              hintText: 'Add another city',
              isDense: true,
            ),
            onSubmitted: (v) {
              final city = v.trim();
              if (city.isNotEmpty) _toggleCity(city, true);
              _customCityController.clear();
            },
          ),
          const SizedBox(height: JobifySpacing.lg),
          Text('Experience', style: theme.textTheme.labelLarge),
          Row(
            children: [
              IconButton(
                onPressed: _minYears == null
                    ? null
                    : () => setState(() =>
                        _minYears = _minYears! > 0 ? _minYears! - 1 : null),
                icon: const Icon(Icons.remove),
              ),
              Text(_minYears == null ? 'Any' : '$_minYears yrs'),
              IconButton(
                onPressed: () =>
                    setState(() => _minYears = (_minYears ?? -1) + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: JobifySpacing.lg),
          Text('Minimum CTC (lakhs)', style: theme.textTheme.labelLarge),
          const SizedBox(height: JobifySpacing.sm),
          TextField(
            controller: _ctcLakhController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              prefixText: '₹ ',
              suffixText: 'L',
              hintText: 'e.g. 5',
              isDense: true,
            ),
          ),
          const SizedBox(height: JobifySpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  final current = ref.read(feedFiltersControllerProvider);
                  ref
                      .read(feedFiltersControllerProvider.notifier)
                      .set(FeedFilters(query: current.query));
                  Navigator.of(context).pop();
                },
                child: const Text('Reset'),
              ),
              const SizedBox(width: JobifySpacing.sm),
              FilledButton(onPressed: _apply, child: const Text('Apply')),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire into `FeedScreen`**

In `app/lib/presentation/feed/feed_screen.dart`: add imports for `feed_filter_bar.dart`, `feed_filters_provider.dart`; insert `const SizedBox(height: JobifySpacing.md), const FeedFilterBar(),` immediately after `const IntrinsicHeight(child: FeedSummaryRow()),`; and replace the `empty:` builder:

```dart
              empty: () {
                final filters = ref.watch(feedFiltersControllerProvider);
                if (filters.isEmpty) {
                  return const JobifyEmptyState(
                    headline: "We're still looking for matches",
                    body: 'Upload a resume to help us find you better roles.',
                    icon: Icons.search_off,
                  );
                }
                return JobifyEmptyState(
                  headline: 'Nothing matches your filters',
                  body: 'Try removing a filter or broadening your search.',
                  icon: Icons.filter_alt_off,
                  primaryAction: TextButton(
                    onPressed: () => ref
                        .read(feedFiltersControllerProvider.notifier)
                        .clear(),
                    child: const Text('Clear filters'),
                  ),
                );
              },
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/feed_filter_test.dart && flutter test test/widget/feed_screen_test.dart`
Expected: PASS (new tests + the untouched feed screen suite).

- [ ] **Step 7: Commit**

```bash
git add app/lib/presentation/feed/ app/test/widget/
git commit -m "feat(app): feed filter bar, filter sheet, filtered empty state"
```

---

### Task 7: Full gates + app CLAUDE.md note

**Files:**
- Modify: `app/CLAUDE.md` (one bullet)

- [ ] **Step 1: Append the invariant to `app/CLAUDE.md`** (in "Non-obvious bits")

```markdown
- **Feed filters are ephemeral by construction** (`feedFiltersControllerProvider`, autoDispose): the provider lives only while `FeedController` (watched by the kept-alive `FeedScreen`) watches it, so sign-out/shell-switch resets filters with no explicit invalidate. `FeedController.build()` **watches** it — a filter change rebuilds from page 1, which is also the cursor reset the backend's cursor-filter-hash binding assumes. Don't convert it to `keepAlive` (would need sign-out invalidation like `preferencesControllerProvider`) and don't pass filters without going through the provider.
```

- [ ] **Step 2: Run every gate, CI-verbatim**

From repo root: all five backend commands from Global Constraints (integration needs local Postgres up — `scripts/start-all.sh` if not running).
From `app/`: `dart format --set-exit-if-changed lib test` · `flutter analyze` · `flutter test`.
Expected: all PASS. Fix anything found before committing.

- [ ] **Step 3: Commit + push branch**

```bash
git add app/CLAUDE.md
git commit -m "docs(app): pin ephemeral feed-filters provider invariant"
git push -u origin feed-filters-search
```

Then open the PR (`gh pr create`) referencing the spec, and hand off to the finishing-a-development-branch flow.
