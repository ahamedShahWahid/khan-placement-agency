# LLM parse-F1 acceptance report

Durable record of the on-demand LLM lane (`test_llm_parser_meets_quality_gate`
in `tests/eval/test_parse_f1_gate.py`). Refresh this file in the same commit as
any prompt, model, or dataset change — the test is the measurement, this file
is the evidence that it was taken. Every number below is copied from the
test's own output; nothing is inferred.

| | |
|---|---|
| Measured | 2026-09-08 00:40 IST |
| Commit | branch `parser/prompt-v2` (spec `docs/superpowers/specs/2026-09-08-extraction-prompt-v3-design.md`) |
| Prompt | v3 (`LLM_PARSER_NAME = "llm.gemini.v2"`) |
| Gated model | `gemini-3.1-flash-lite` — the new production default |
| Transport | interactive `parse_text` — the same call the live parse path makes |
| Pacing | `JOBIFY_PARSE_EVAL_DELAY_S=2`; test printed `Retries: 0`; 139s for 32 resumes |
| Result | **PASS** — overall 0.973 against the 0.90 floor; every per-field floor met, including the four new ones |

## Gated run

| Set | name | email | phone | skills | languages | experience | education | certifications | **overall** |
|---|---|---|---|---|---|---|---|---|---|
| synthetic (20) | 1.000 | 1.000 | 1.000 | 0.891 | 1.000 | 1.000 | 0.966 | 1.000 | **0.973** |
| real (12, local only) | 0.917 | 1.000 | 1.000 | 0.789 | 1.000 | 0.962 | 0.704 | 0.880 | 0.926 |

Synthetic counts: skills TP 240 / FP 7 / FN 52; languages 3/0/0; experience
50/0/0; education 28/1/1; certifications 21/0/0.

**No invented skills.** The 7 FPs are phrases in the text ("inventory
accuracy", "academic audits", "cluster-wide monitoring", "delivery app") that
the gold's tie-breaker classes as duties or deliverables. The 52 FNs are the
prompt's "when in doubt, leave it out" bias at work on prose competencies —
"FMCG distribution", "full-and-final settlement", "vendor reconciliation" —
plus a handful of tools named only in stack lines (Vertex AI, Hadoop, jq).
Trading those misses for precision is deliberate: an over-full skills list
on a profile is worse for matching than a short accurate one.

## Why the numbers changed, in order

| Report | Gold | Prompt | Gated model | Synthetic |
|---|---|---|---|---|
| 2026-09-07 morning | 4 fields, `[]` on non-tech rows | v1 | 2.5 Flash | 0.982 |
| 2026-09-07 night (yardstick) | 8 fields, skills rule, real set | v1 | 2.5 Flash | 0.955 |
| **2026-09-08 (this)** | same | **v3** | **3.1 Flash-Lite** | **0.973** |

Three prompts × three models × two sets, one run each (from the
comparison lane; gated column in bold):

| prompt | 2.5 Flash syn / real | 3.1 Flash-Lite syn / real | 3.5 Flash-Lite syn / real |
|---|---|---|---|
| v1 | 0.955 / 0.939 | 0.966 / 0.922 | 0.966 / 0.911 |
| v2 | 0.936 ✗ / 0.917 | 0.964 / 0.948 | 0.961 / 0.901 |
| v3 | 0.952 / 0.937 | **0.973 / 0.926** | 0.970 / 0.915 |

Skills FPs on v3, synthetic: 2.5 Flash **97**, 3.1 Flash-Lite **7**, 3.5
Flash-Lite 4. v2 (a permissive "every competency stated in prose" rule with
positive examples only) sent 2.5 Flash to 146 FPs and under the floor while
the lite models barely moved — the negative classes had to be spelled out.

**Model choice.** 3.1 Flash-Lite wins the synthetic set outright, is within
0.011 of 2.5 Flash on the real set with a fraction of its false positives,
and costs $0.25 / $1.50 per 1M tokens against $0.30 / $2.50. 3.5 Flash-Lite
is priced like 2.5 Flash and scores between them. 2.5 Flash-Lite is closed
to new users. Parser default is therefore `gemini-3.1-flash-lite`.

**Real set remains the harder number** (skills 0.79, education 0.70): dense
prose, five of twelve without section headers, a letter-spaced PDF and a
WhatsApp-forwarded DOCX. This is the figure that describes the product.

## Report-only floors, now set

From this baseline, LLM lane only: languages ≥ 0.75 (3 gold items — wide on
purpose), experience ≥ 0.95, education ≥ 0.90, certifications ≥ 0.90.
`overall` is still the mean of the original four.

## Appendix — explainer model side-by-side (synthetic contexts)

Six match contexts, both models, prompt unchanged, `language="hi"` on the
last. The question was whether the explainer should follow the parser onto
3.1 Flash-Lite. **It should not**: the lite model writes warmer second-person
copy but invents facts that are not in the prompt (there is no "four years",
"three years", or "current salary" anywhere in the context). 2.5 Flash is
literal and grounded. Grounding wins for a surfaced explanation, so
`match_explainer_model` stays `gemini-2.5-flash`. One 2.5 Flash defect
surfaced here and is fixed in the same PR: the literal string `"None"` as a
caveat is now treated as no caveat.

| Case | 2.5 Flash | 3.1 Flash-Lite |
|---|---|---|
| Strong local fit | fit: "…strong fit given their Bengaluru location, 3-6 years of experience, and expected compensation aligning…" · caveat: `"None"` (literal — now blanked) | fit: "Your **four years of backend experience** and local residency align perfectly…" · caveat: "Your expected compensation is near the top of the budget…" (2.0M vs 2.4M max) |
| Location mismatch | caveat: "The candidate's location in Kolkata is a significant mismatch for the Pune-based role." | fit: "Your **three years of QA experience** align perfectly…" · caveat: "You will need to relocate from Kolkata to Pune…" |
| Under-experienced | caveat: "…experience level is below the preferred band for a Senior Architect position." | caveat: "…below the preferred ten-year threshold…" |
| CTC above budget | caveat: "…expected compensation significantly exceeds the job's maximum CTC." | caveat: "Your salary expectations significantly exceed the maximum compensation offered…" |
| Non-tech ops | fit: "…strong fit for the Warehouse Shift Lead role at Delhivery, matching location, experience, and compensation…" · caveat: empty | fit: "…relevant logistics experience…" · caveat: "…offered compensation **falls slightly below your current salary requirements**" (applicant 3.8L, job max 4.2L — false) |
| Hindi, teacher | fit in Devanagari, names the location and 5-12 year band; caveat notes location fit is not the strongest (component 0.80 — correct) | fit in Devanagari; caveat: expected CTC is "close to the budget, negotiation may be needed" (5.4L vs 6.0L — invented concern) |

## How to re-run

```
JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm
```

- Gated model = `JOBIFY_RESUME_PARSER_MODEL` (default `gemini-3.1-flash-lite`).
  `JOBIFY_PARSE_EVAL_MODELS=a,b,c` compares models in one run; the first
  is gated. `JOBIFY_PARSE_EVAL_DELAY_S=0` on a paid-tier key.
- Reads the real key from `JOBIFY_GEMINI_API_KEY` in `.env`, copied by
  `tests/conftest.py` to `JOBIFY_EVAL_GEMINI_API_KEY` under this opt-in. If
  the key is absent the test **skips** (`1 skipped`) — never republish
  these tables from a skipped run.
- A depleted prepaid key fails on the first example within seconds
  (`_is_retryable` recognises the "prepayment credits are depleted" body).
  A `403 PERMISSION_DENIED` means the key's project has no billing; a
  top-up won't fix it. Allow ~1 minute after a top-up.
- The real set is scored when `sample_resume/` (or
  `JOBIFY_PARSE_EVAL_REAL_DIR`) exists. Its output is aggregate counts
  only; never paste its token diffs anywhere.
- Replace the tables above from the printed summaries and commit alongside
  whatever prompt, model, or dataset change prompted the re-run.
