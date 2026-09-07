# Extraction prompt v3 + parser model choice — design

**Date:** 2026-09-08 · **Status:** implemented
**Parent:** "Better extraction at a chosen price" — sub-project 2 of 3.
Depends on sub-project 1 (`2026-09-07-extraction-yardstick-design.md`).

## Why

With the yardstick in place, the gated parser (2.5 Flash, prompt v1) scored
0.955 with **zero invented skills on tech resumes** but 68 skills misses —
every one a competency the resume states in prose ("distributed systems",
"FMCG distribution", "team management") that the v1 instruction ("extract
ONLY information explicitly present … a list with no stated items stays
empty") never asked it to lift out. Its 31 false positives were paraphrases
and trait phrases on the three non-tech resumes. Education misses were
degree/field bundling ("MBA Marketing" as the degree).

## What changed

**Prompt v3** (`LLM_PARSER_NAME = "llm.gemini.v2"` — provenance bumped
because the fields' meaning changed). Rules map 1:1 to measured error
classes:

- skills = (a) every named tool/technology wherever it appears, plus (b)
  competency/domain terms *a recruiter would search for* that the resume
  states the person practises — the yardstick's own tie-breaker, in the
  prompt. Explicit negatives for the classes the first rewrite (v2)
  produced: coursework, deliverable/product names, duties restated as
  nouns, KPIs, traits. "When in doubt, leave it out."
- degree = qualification name only; field = branch. No career-break rows.
  Certifications only from a credentials heading or clear presentation.
- languages unchanged (added in sub-project 1).

**Why v2 was thrown away.** v2 said "every competency the resume states the
person has or did, from prose" with four positive examples. 2.5 Flash took
it literally: FN 68 → 32 but FP 31 → **146** (skills 0.745, below the 0.75
floor), listing "payments orchestrator" despite that exact phrase being in
the exclusion list. The lite models barely moved. Lesson: a permissive
inclusion rule needs the *negative* classes spelled out and a precision
bias, or the larger model over-generates.

**Parser model → `gemini-3.1-flash-lite`.** Three prompts × three models ×
two sets, single runs each:

| prompt | 2.5 Flash syn / real | 3.1 Flash-Lite syn / real | 3.5 Flash-Lite syn / real |
|---|---|---|---|
| v1 | 0.955 / 0.939 | 0.966 / 0.922 | 0.966 / 0.911 |
| v2 | 0.936 ✗ / 0.917 | 0.964 / 0.948 | 0.961 / 0.901 |
| **v3** | 0.952 / 0.937 | **0.973 / 0.926** | 0.970 / 0.915 |

On v3, 3.1 Flash-Lite has 7 skills FPs on the synthetic set vs 97 for
2.5 Flash, and costs $0.25 / $1.50 per 1M tokens vs $0.30 / $2.50. 3.5
Flash-Lite is priced like 2.5 Flash and scores between the two. 2.5
Flash-Lite is closed to new users.

**Explainer model stays `gemini-2.5-flash`.** A six-context side-by-side
(synthetic contexts, appendix of `LLM_EVAL_REPORT.md`) showed 3.1 Flash-Lite
writing warmer second-person copy that **invents facts not in the prompt**
("your four years of backend experience", a compensation caveat that
contradicts the numbers). 2.5 Flash is literal and grounded. Grounding wins
for a surfaced explanation. One 2.5 Flash defect found and fixed: the
literal string `"None"` returned as a caveat is now treated as no caveat.

**Report-only floors set** (LLM lane only) from the v3 / 3.1 Flash-Lite
baseline with margin: languages 0.75, experience 0.95, education 0.90,
certifications 0.90. `overall` unchanged.

## Not in scope

Explainer prompt changes; deriving `years_experience` from the parsed
timeline; messy input (sub-project 3); re-authoring gold (the v2 → v3
FP lists were checked against the gold rule — the gold held).

## Acceptance

- Gated lane (`gemini-3.1-flash-lite`, prompt v3) passes 0.90 overall and
  every per-field floor including the four new ones; `Retries: 0`.
- `LLM_EVAL_REPORT.md` refreshed with the v3 comparison and the explainer
  appendix.
- Unit: placeholder-caveat test; existing parser/explainer tests green.
