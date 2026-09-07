# LLM parse-F1 acceptance report

Durable record of the on-demand LLM lane (`test_llm_parser_meets_quality_gate`
in `tests/eval/test_parse_f1_gate.py`). Refresh this file in the same commit as
any prompt, model, or dataset change — the test is the measurement, this file
is the evidence that it was taken. Every number and token below is copied
from the test's own output; nothing is inferred.

| | |
|---|---|
| Measured | 2026-09-07 19:47 IST |
| Commit | `c9f5313` (main) — parser/prompt/dataset unchanged by the PR that adds this file |
| Model | `gemini-2.5-flash` (test default; no `JOBIFY_RESUME_PARSER_MODEL` override in `.env`) |
| Transport | interactive `parse_text` — the same call the live parse path makes |
| Pacing | `JOBIFY_PARSE_EVAL_DELAY_S=7` (default); test printed `Retries: 0`; 190s wall clock |
| Key tier | prepaid (recharged 2026-09-07) |
| Result | **PASS** — overall 0.982 against the 0.90 acceptance floor |

## Per-field F1 (20 gold examples, four gated fields)

| Field | LLM F1 | TP | FP | FN | Floor | Library F1 (same commit) |
|---|---|---|---|---|---|---|
| name | 1.000 | 20 | 0 | 0 | 0.70 | 0.850 |
| email | 1.000 | 19 | 0 | 0 | 0.95 | 0.973 |
| phone | 1.000 | 20 | 0 | 0 | 0.85 | 1.000 |
| skills | 0.929 | 202 | 16 | 15 | 0.75 | 0.883 |
| **overall** | **0.982** | | | | **0.90** | 0.927 |

`email` TP is 19 because example 019 has no email by design (phone-only
resume); the model returned null there, which scores as neither TP nor FP.
The library column is the deterministic CI lane run at the same commit; its
authoritative home is `000_README.md`, it is repeated here only for the
comparison.

## Per-example

Every example except 005, 013 and 014 scores ≥ 0.97. Every name, email and
phone prediction across all twenty was exact, so all variance is in
`skills`. The FP/FN columns list the actual tokens the test printed, after
the scorer's own case-fold normalisation.

| Example | F1 | skills TP/FP/FN | FP tokens | FN tokens |
|---|---|---|---|---|
| 001 priya-software-engineer | 1.000 | 13/0/0 | | |
| 002 arjun-data-scientist | 1.000 | 14/0/0 | | |
| 003 divya-frontend-dev | 0.982 | 13/1/1 | `tailwind css` | `tailwind` |
| 004 rohan-fresher | 1.000 | 11/0/0 | | |
| 005 sneha-product-manager | 0.883 | 4/7/0 | `amplitude` `confluence` `figma` `jira` `looker` `mixpanel` `tableau` | |
| 006 vikram-devops-lead | 1.000 | 18/0/0 | | |
| 007 aisha-mobile-dev | 0.987 | 9/1/0 | `firebase` | |
| 008 karthik-ml-engineer | 1.000 | 13/0/0 | | |
| 009 meera-sales-manager | 1.000 | 8/0/0 | | |
| 010 tabular-devjyoti-qa | 0.979 | 11/1/1 | `rest api` | `rest` |
| 011 anand-career-gap | 0.989 | 11/0/1 | | `aws` |
| 012 fresher-projects-riya | 0.976 | 14/0/3 | | `render` `vercel` `websocket` |
| 013 suresh-ops-executive | 0.750 | 0/2/0 | `excel` `wms software` | |
| 014 kavitha-teacher | 0.750 | 0/4/0 | `academic audits` `lesson planning` `ms office` `report cards` | |
| 015 rahul-senior-architect | 0.972 | 24/0/6 | | `aws` `ci/cd` `event sourcing` `microservices` `php` `sql` |
| 016 hinglish-pooja-hr | 1.000 | 8/0/0 | | |
| 017 unconventional-headers-dev | 0.979 | 11/0/2 | | `kafka` `terraform` |
| 018 certs-heavy-cloudops | 0.990 | 12/0/1 | | `google cloud` |
| 019 phone-only-imran | 1.000 | 0/0/0 | | |
| 020 name-midheader-lakshmi | 1.000 | 8/0/0 | | |

## Reading the skills number

**No FP is an invented skill.** Each of the 16 FP tokens was grepped in its
resume text and found there. That is the one error class this gate exists
to catch (the prompt's "never infer or invent" contract), and it did not
occur. The 16 split into three kinds:

- **2 are granularity mismatches, not errors** (003 `tailwind css` vs the
  expected `tailwind`; 010 `rest api` vs `rest`). Each scores as one FP
  plus one FN, so they account for 2 of the 15 FNs as well. The scorer
  matches whole normalised tokens, so a more specific answer than the gold
  file is penalised twice.
- **8 are gold-file omissions of tokens the resume states outright.** 005's
  text has a literal `SKILLS` block naming SQL, Python, Mixpanel, Amplitude,
  Looker, Tableau, Figma, Jira, plus Confluence in a role bullet; the
  expectation lists only `agile`, `kanban`, `python`, `sql`. 007's resume
  names Firebase twice. These are authoring gaps of the kind
  `000_README.md`'s "Adding examples" step 3 says to fix, and they are the
  cheapest 0.02 of skills F1 available. Not edited in this PR because the
  gold data is shared with the library lane and changing it moves the
  baseline figures recorded in `000_README.md` and `core/CLAUDE.md`; do it
  as its own dataset commit that refreshes all three.
- **6 land on examples whose expectation is `[]`** (013: 2, 014: 4). Three
  gold files expect no skills at all — 013, 014 and 019 — and the parser
  extracted skill-like phrases from the first two. Both `excel` and
  `wms software` are in 013's text; all four 014 tokens are in its text.
  Whether "lesson planning" or "report cards" is a *skill* for a teacher
  is a product question about non-tech applicants, not a parser question;
  until it is answered those two rows cap at 0.750 no matter what the
  model does, and 019's 1.000 depends on the model continuing to return
  nothing for a delivery-ops resume full of skill-like prose. The rule
  in `000_README.md` against tuning ground truth to flatter the parser
  applies to exactly this judgment-call class.

**The 15 FNs are genuine recall misses**: every FN token was grepped in its
resume text and found there. 13 of them are outright misses (2 are the
granularity pairs above). They cluster on 015 (6 of 30 expected skills
missed; the longest resume) and 012 (3 of 17), with singletons on 011, 017
and 018. `aws` is missed twice (011, 015). No pattern beyond "longer skill
lists lose a few" is supported by two examples.

**Non-determinism.** Two consecutive runs at the same settings on the same
commit agreed on every example except 014, which returned 9 skills in the
first run and 4 in the second (skills F1 0.918 → 0.929, overall 0.980 →
0.982). A separate one-off re-call of 014 also returned 4. Scalar fields did
not vary. Since every FP and FN is scored by pooled counts across the 20
examples, a swing of that size moves overall by ~0.002; the floor is 0.08
away.

## Versus the library parser

The LLM lane improves every gated field except `phone`, which both parsers
max out. The gains are exactly where the library parser is documented as
weak: `name` 0.850 → 1.000 (regex header heuristics vs. reading the
document), and `skills` FN 43 → 15 — the non-tech vocabularies (009, 016,
020) go from near-zero recall to perfect. The library parser remains the CI
gate at 0.85 because it is deterministic and free; this lane is the
acceptance measurement and runs on demand only.

## How to re-run

```
JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm
```

- Reads the real key from `JOBIFY_GEMINI_API_KEY` in `.env`, which
  `tests/conftest.py` copies to `JOBIFY_EVAL_GEMINI_API_KEY` under this
  opt-in. If the key is absent the test **skips** (output says `1 skipped`,
  not `1 passed`) — never republish these tables from a skipped run.
- A depleted prepaid key fails on example 001 within seconds: `_is_retryable`
  recognises the "prepayment credits are depleted" body and does not back
  off. A `403 PERMISSION_DENIED` instead means the key belongs to a project
  without billing — a different problem that a top-up will not fix. After a
  top-up allow about a minute for it to propagate.
- On a paid-tier key add `JOBIFY_PARSE_EVAL_DELAY_S=0`; the 7s default
  exists for the free tier's per-minute ceiling and costs ~2 minutes of
  idle time per run.
- The test prints the summary, per-example breakdown, retry count, and the
  per-example skills token diff. Replace the tables above from that output
  and update the header block; commit alongside whatever prompt, model, or
  dataset change prompted the re-run.
