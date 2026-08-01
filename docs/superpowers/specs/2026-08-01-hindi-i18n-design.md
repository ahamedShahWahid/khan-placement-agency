# Hindi i18n (roadmap slice 5) — design

Approved by Ahamed 2026-08-01. Implements `IMPLEMENTATION_SPEC.md` §3.7
(`flutter_localizations` + ARB, English + Hindi, no RTL) at the scope chosen
during brainstorming: **the full applicant experience speaks Hindi** — app UI,
match explanations, notifications, and applicant-bound emails. Recruiter/admin
surfaces (web console, invite emails) stay English.

Decisions made during brainstorming:

- **Scope: everything applicant-facing.** UI chrome + backend-generated
  content (explanations, notification/email copy). Recruiter & admin = English
  only (their console and `employer_invite` emails never localize).
- **Rescore on switch.** Explanations are generated in the applicant's
  preferred language at scoring time; a language change triggers the existing
  preferences rescore path, so explanations regenerate in the new language
  via normal worker flow. No dual-language generation, no read-time
  translation.
- **In-app notification copy localizes client-side for free** — notifications
  store `kind` + structured `payload` (never rendered text); the Flutter
  inbox renders copy from them, so ARB covers it. Only the email channel
  renders server-side.
- Emails render from the Python string table `_render(kind, payload)` in
  `integrations/notifications/ses.py` (the `core/emails/templates/*.html`
  files are design assets, not the render path) — Hindi is a second string
  table, not new template files.

## 1. Language preference substrate (backend)

- **`applicant_preferences.language`** — varchar + CHECK (`'en'`,`'hi'`),
  NOT NULL, default `'en'`. New Alembic migration (column + CHECK only; the
  server default covers existing rows). Same no-PG-enum precedent as
  `desired_role`/`rating`.
- **`AppLanguage` StrEnum** (`EN = "en"`, `HI = "hi"`) at the boundary;
  varchar in DB.
- Exposed on the existing **GET/PATCH `/v1/applicants/me/preferences`**:
  response gains `language`; PATCH accepts `Literal["en","hi"]`. Partial-update
  contract unchanged — `language` is non-nullable (omitted = untouched;
  explicit null is 422).
- **`language` joins `_PREFERENCES_MATCHING_FIELDS`** (the PATCH rescore
  trigger set): switching stages the standard rescore whose workers
  regenerate explanations inline — that IS "rescore on switch". Scores
  recompute identically; only explanation text changes. (`desired_role`
  remains a non-trigger; don't confuse the two.)
- **DSR:** `applicant_preferences` is already exported + hard-deleted; the
  new column rides along automatically (export dumps all columns). No new
  PII table.

## 2. Flutter l10n

- `flutter_localizations` + `gen_l10n`: `app/lib/l10n/app_en.arb` (source of
  truth, `@` description metadata per key) + `app_hi.arb` (Devanagari).
  `l10n.yaml` at `app/`; generated `AppLocalizations` consumed as
  `context.l10n`-style extension (one small helper).
- **All applicant-facing UI strings externalize** (~300 `Text(` sites plus
  hints, tooltips, snackbars, dialogs, semantic labels): screens, buttons,
  empty states, in-app notification copy (rendered from `kind`+payload),
  application stage display labels (`applied`→`आवेदन किया`,
  `shortlisted`→`शॉर्टलिस्ट`, …). **Wire values never translate** — enums,
  slugs, and API params stay English; only display strings localize.
- **Locale resolution:** signed-out → device locale (`hi` → Hindi, else
  English). Signed-in → the server preference wins, loaded via the existing
  keepAlive `preferencesControllerProvider`. A `localeController` provider
  owns `MaterialApp.locale`; every sign-out-like path already invalidates
  the preferences provider, which resets the locale to device default.
- **Switcher:** a Profile-screen row (`English / हिन्दी`) → PATCHes
  `language` through the existing preferences controller (its
  `copyWithPrevious` save semantics and error handling apply) and flips the
  locale optimistically; a failed PATCH rolls back through the controller's
  error path.
- **Numbers/dates:** the existing IST/₹/lakh formatting stays; Hindi UI
  keeps Latin digits (standard for Indian apps — no Devanagari numerals).
- **Fonts:** verify the current font stack renders Devanagari; if not, add
  Noto Sans Devanagari through the existing google_fonts path. Widget tests
  keep `ThemeData.light(useMaterial3: true)` (no network fonts in tests).

## 3. Explanations (templated + LLM)

- `ExplainContext` gains `language: str = "en"`. Both score workers resolve
  it from the SAME outer-joined `applicant_preferences` row they already
  read for scoring (soft-delete predicate stays in the JOIN's ON clause;
  missing row → `"en"`).
- **`TemplatedExplainer`:** hand-written Hindi variants of every fit/caveat
  template, same substitution slots. Selection by `ctx.language`.
- **`GeminiMatchExplainer`:** when `language == "hi"`, the system
  instruction appends an "answer in Hindi (Devanagari), same JSON shape"
  directive; schema/caps/`thinking_budget=0` unchanged. **Every failure path
  falls back to the Hindi templated text** — an applicant who chose Hindi
  never sees English fallback prose. `LLM_GENERATOR_VERSION` bumps (semantic
  prompt change — flagged per the pinned rule).

## 4. Emails (applicant-bound kinds only)

- `_render(kind, payload)` → `_render(kind, payload, language)`. A Hindi
  string table sits beside the English one — same kinds, same payload slots,
  subjects localized too. Kinds localized: `application_received`,
  `application_stage_changed` (all stage arms incl. the neutral rejection
  copy), `match_surfaced`, `dsr_export_ready`. **`employer_invite` always
  renders English** (recruiter-bound).
- The notification sweep resolves the recipient's language once per
  dispatch: user → applicant → live preferences (outer join, default
  `"en"`); recruiters/admins have no applicant row → English. Both SES and
  logging channels take the language parameter.

## 5. Testing

- **Backend:** migration applies; preferences PATCH round-trip en↔hi + 422
  on junk/null; language change stages a rescore while a `desired_role`
  change still doesn't (trigger-set pin); explainer units per language incl.
  LLM-failure → **Hindi** templated fallback; `_render` matrix test — every
  localized kind × {en, hi} renders subject+body with slots filled and no
  literal `{` leftovers; `employer_invite` renders English even with
  `language="hi"`; sweep resolves a recruiter recipient to English.
- **Flutter:** ARB parity test (en/hi key sets identical); a
  **no-hardcoded-strings guard** — a test that mechanically scans
  `lib/presentation` for string-literal `Text(`/`hintText:` occurrences
  outside an explicit allowlist (mechanical-scan lesson: agents miss
  copy-paste sprawl; the guard keeps drift out permanently); widget tests
  pumping key screens under `Locale('hi')` asserting Devanagari copy
  renders and nothing throws; switcher test (tap हिन्दी → PATCH called with
  `language: "hi"` + locale flips; failed PATCH → locale rolls back).
- **Translation quality:** Hindi strings are authored in-repo (Claude) and
  flagged in the PR for native-speaker review before launch; the ARB format
  makes post-review corrections one-line edits.

## 6. Out of scope

- Recruiter/admin web console, `employer_invite` email, marketing site.
- RTL, Devanagari numerals, any third language (ARB structure gives the
  slot for free, nothing else).
- Translating stored historical data — explanations regenerate only via the
  rescore-on-switch path; old notification emails are sent and gone.
- Server-side locale negotiation (`Accept-Language`) — the stored preference
  is the only server-side signal.
