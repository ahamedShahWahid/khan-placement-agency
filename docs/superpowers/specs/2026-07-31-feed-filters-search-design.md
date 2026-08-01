# Feed filters & search (application-stages slice B) — design

Approved by Ahamed 2026-07-31. Closes the slice B debt deferred by
`2026-07-19-application-stages-design.md`.

## Goal

Let an applicant narrow their ranked match feed with filters (location,
experience fit, minimum CTC) and a keyword search over job title + employer
name. Filters are ephemeral (per-session, client-held), operate **only within
the matched feed** (surfaced matches — "job will find you" is unchanged; this
is not a browse-all-jobs surface), and never alter ranking: ordering stays
`(total_score DESC, id DESC)`.

Decisions made during brainstorming:

- Filters: location, experience fit, min CTC, keyword search — all four.
- Keyword search scope: title + employer name only (not description).
- Persistence: none server-side, none on-device. Query params only; the
  Flutter controller holds them for the session.
- Search pool: matched feed only. No new endpoint; no new ordering.

## API contract — `GET /v1/feed` gains four optional query params

All params absent ⇒ behavior byte-identical to today (existing feed tests must
pass unmodified). Params compose with AND. Response shape unchanged.

| Param | Type / validation | Semantics |
|---|---|---|
| `q` | `str`, trimmed, 1–100 chars; pure-whitespace treated as absent | Case-insensitive substring match on `job.title` OR `employer.name`. `ILIKE '%…%'` with `\`, `%`, `_` escaped. |
| `location` | `str`, repeatable (`?location=Pune&location=Remote`), each 1–100 chars | Job matches if **any** requested location appears in `job.locations` (case-insensitive equality per element). |
| `min_years` | `int ≥ 0` | The applicant's years of experience. Job matches if `min_exp_years <= min_years <= max_exp_years` (experience-*fit*, not a range slider). |
| `min_ctc` | `Decimal ≥ 0`, absolute ₹ (same unit as `jobs.ctc_min/ctc_max`) | Job matches if `ctc_max IS NULL OR ctc_max >= min_ctc`. **Jobs with undisclosed CTC stay visible** — filtering them out would punish employers for not listing pay; at MVP volume recall beats precision. |

Validation failures → FastAPI 422 (existing convention). No new error slugs.

## Query semantics

Filter predicates append as extra `WHERE` clauses to the existing single feed
statement in `jobify_api.routes.feed`. Untouched: the score ordering, the
peek-one `LIMIT limit+1`, the thumbs-down exclusion outer join (ON-clause
predicates), `require_applicant`, and the 401/403 ladder.

- Location: `jobs.locations` is a Postgres `ARRAY(String(100))` — predicate is
  `EXISTS (SELECT 1 FROM unnest(jobs.locations) e WHERE lower(e) IN
  (:wanted_lowercased))`. Fine at MVP scale; no new index, **no migration**.
- Keyword: `job.title ILIKE :pat OR employer.name ILIKE :pat` with the pattern
  escaped server-side (SQLAlchemy `ilike(..., escape="\\")`).

## Cursor binds to its filter set

The opaque cursor payload (`{score, match_id}`) gains an `f` field: a short
hash (e.g. first 12 hex chars of sha256) of the canonicalized filter set —
params sorted by key, values lowercased/trimmed, repeated `location` values
sorted. On decode:

- cursor `f` ≠ hash of current request params → `400 invalid_cursor`
  (existing slug). A cursor minted under different filters can never silently
  serve wrong pages.
- Legacy cursor with no `f` field (minted pre-deploy) = filterless: valid only
  if the current request also has no filters, else `400 invalid_cursor`.

Flutter resets its cursor on every filter change, so clients never hit the 400
in practice; on receiving it anyway `loadNextPage` surfaces it through the
shared paging error state (`AsyncValue.error(...).copyWithPrevious(...)`,
preserving already-loaded items) and the feed screen's error view offers a
manual Retry button that calls `FeedController.refresh()` — there is no
automatic cursor-drop-and-refetch.

**ETag needs no change** — it already keys off `(applicant_id, max(updated_at),
count)`; filtered responses produce their own counts, so 304 semantics stay
correct per filter set.

## Flutter UI

- **Filter bar** under the feed summary row: a debounced (~400 ms) search
  `TextField` + a "Filters" button opening a bottom sheet — location
  multi-select chips (small hardcoded city list + free-text add), experience
  stepper, min-CTC field in lakhs (converted to absolute ₹ per the existing
  lakh convention).
- Active filters render as dismissible chips; "Clear all" resets to the plain
  feed.
- `FeedController` holds an immutable `FeedFilters` value object — ephemeral,
  provider-held (survives tab switches, gone on app restart). Any change ⇒
  reset cursor + `refresh()`.
- **Empty state branches on `filters.isEmpty`**: "no matches yet" (unchanged)
  vs "nothing matches your filters" with a Clear-filters CTA.
- The 3-tile summary row keeps showing **unfiltered** totals — it is a home
  summary, not a result count. (Avoids "3 new matches" beside a filtered empty
  list reading as a bug.)

## Error handling & edge cases

- `400 invalid_cursor` on filter/cursor mismatch → paging error view with a
  manual Retry button (`FeedController.refresh()`); no automatic cursor drop.
- ILIKE metacharacters (`%`, `_`, `\`) in `q` are escaped — a literal search
  for `100%` matches literally.
- No audit/PII implications: filters are the applicant's own query over their
  own feed; nothing new is logged or stored.

## Testing

API integration (extend the existing feed suite):

- Each filter alone + all composed; results stay score-ordered.
- `min_ctc`: job with `ctc_max NULL` remains visible; job below threshold
  drops.
- Location case-insensitivity; multi-`location` OR semantics.
- `q` ILIKE-escape: `%`/`_` treated literally; employer-name match; whitespace
  `q` ignored.
- Cursor: filtered pagination across pages; filter-hash mismatch → 400; legacy
  `f`-less cursor accepted filterless, rejected with filters.
- OpenAPI snapshot updated once (new query params only).
- Existing feed tests pass unmodified (proves the no-params path untouched).

Flutter:

- Controller: filter change resets cursor + refetches; `FeedFilters` equality.
- Widget: filtered-empty state shows Clear CTA; unfiltered empty state
  unchanged.
- API/DTO: query-param serialization incl. repeated `location`.

## Out of scope

- Browse/search across all open jobs (separate discovery surface, own spec if
  ever wanted).
- Server- or device-persisted filters.
- Description full-text search / tsvector ranking.
- Any change to scoring, surfacing, or the summary tiles.
