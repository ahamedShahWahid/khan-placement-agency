# LLM parse-F1 acceptance report

Durable record of the on-demand LLM lane (`test_llm_parser_meets_quality_gate`
in `tests/eval/test_parse_f1_gate.py`). Refresh this file in the same commit as
any prompt, model, or dataset change — the test is the measurement, this file
is the evidence that it was taken. Every number below is copied from the
test's own output; nothing is inferred.

| | |
|---|---|
| Measured | 2026-09-07 23:48 IST |
| Commit | branch `eval/extraction-yardstick` (yardstick spec `docs/superpowers/specs/2026-09-07-extraction-yardstick-design.md`) |
| Gated model | `gemini-2.5-flash` (production default) |
| Compared | `gemini-3.1-flash-lite`, `gemini-3.5-flash-lite` (informational) |
| Transport | interactive `parse_text` — the same call the live parse path makes |
| Pacing | `JOBIFY_PARSE_EVAL_DELAY_S=2`; test printed `Retries: 0`; 422s for 3 models × 32 resumes |
| Result | **PASS** — gated overall 0.955 against the 0.90 floor |

## What changed since the 2026-09-07 morning report (0.982)

The yardstick, not the parser. Same commit's parser, same prompt except a
`languages` field, but the gold files now:

- list **non-tech competencies** on 013/014/019 (previously `[]`) and every
  tool a resume names in prose (005's Jira/Figma/…, 007's Firebase), under
  the skills rule in `000_README.md`;
- carry **all eight fields** — `languages`, `experience`, `education`,
  `certifications` are scored and printed but **report-only**; `overall`
  is still the macro mean of name/email/phone/skills, so 0.90 means what
  it meant;
- are joined by a **real set** of 12 applicant resumes (local only,
  gitignored PII; aggregate counts only below).

So the drop from 0.982 to 0.955 is the metric finally seeing what it was
blind to. The library parser moved 0.927 → 0.886 for the same reason.

## Comparison (F1 per field)

| Model | Set | name | email | phone | skills | languages | experience | education | certifications | **overall** |
|---|---|---|---|---|---|---|---|---|---|---|
| 2.5 Flash (gated) | synthetic | 1.000 | 1.000 | 1.000 | 0.819 | 0.857 | 0.990 | 0.897 | 1.000 | **0.955** |
| 2.5 Flash | real | 1.000 | 1.000 | 1.000 | 0.756 | 1.000 | 1.000 | 0.800 | 0.917 | 0.939 |
| 3.1 Flash-Lite | synthetic | 1.000 | 1.000 | 1.000 | 0.863 | 1.000 | 0.990 | 1.000 | 0.977 | 0.966 |
| 3.1 Flash-Lite | real | 0.917 | 1.000 | 1.000 | 0.772 | 1.000 | 0.962 | 0.741 | 0.880 | 0.922 |
| 3.5 Flash-Lite | synthetic | 1.000 | 1.000 | 1.000 | 0.863 | 1.000 | 0.990 | 1.000 | 0.952 | 0.966 |
| 3.5 Flash-Lite | real | 0.917 | 1.000 | 1.000 | 0.726 | 1.000 | 0.962 | 0.667 | 0.880 | 0.911 |
| library parser | synthetic | 0.850 | 0.973 | 1.000 | 0.721 | 0.000 | 0.000 | 0.000 | 0.000 | 0.886 |
| library parser | real | 0.522 | 1.000 | 0.917 | 0.286 | 0.000 | 0.000 | 0.057 | 0.000 | 0.681 |

Gated-model synthetic counts: skills TP 224 / FP 31 / FN 68; languages
3/1/0; experience 50/1/0; education 26/3/3; certifications 21/0/0.

## Reading the numbers

**Scalar fields are solved** by every LLM model on both sets (one name
miss on the real set for the lite models). The library parser's real-set
name F1 of 0.522 is what the LLM lane replaces.

**Skills: the misses are now the story, and they are a prompt gap.** On
the 17 tech-and-mixed synthetic rows 2.5 Flash has **zero** skills FPs. Its
68 FNs are competencies the resume states in prose — "distributed
systems", "FMCG distribution", "team management", "Darwinbox", "GKE" — that
the current instruction ("extract ONLY information explicitly present … a
list with no stated items stays empty") never asks it to lift out of
sentences. All 31 of its FPs sit on the three non-tech rows (013: 7,
014: 16, 019: 8) and are paraphrases ("customer escalation resolution" for
"handle escalations") or trait phrases ("calm under pressure", "clear
communication") — grounded in the text, wrong under the skills rule. The
lite models paraphrase far less (FP 10 and 7) and score higher on skills
as a result; that reverses the morning's ranking, when the gold rewarded
saying nothing on those rows.

**Education is a convention field.** The first run of this yardstick scored
0.59–0.72 because the prompt says copy verbatim ("Anna University,
Chennai") while gold was authored bare. The scorer now drops a trailing
location/qualifier from organisation keys on both sides and the field
reads 0.90–1.00. The three remaining 2.5 Flash mismatches bundle the branch
into the degree ("MBA Marketing", "B.Tech IT") or add a qualifier
("Intermediate" vs "Intermediate (12th)") — a degree-vs-field instruction
for the prompt.

**Experience and certifications are essentially solved** on the synthetic
set (one extra experience entry, a "Career Break" row, from every model).
On the real set experience is 0.96–1.00 and certifications 0.88–0.92.

**Real set is harder across the board** (skills 0.73–0.77, education
0.67–0.80): denser prose, missing section headers on 5 of 12, one
letter-spaced PDF (now recovered by the extractor fix in this branch), one
WhatsApp-forwarded DOCX. This is the number that describes the product.

**Model choice, on this yardstick:** the two lite models tie with 2.5 Flash
on the scalar fields and beat it on skills and education for the synthetic
set; 2.5 Flash is best on the real set's skills and education. Nothing here
justifies a switch before the prompt work — the skills FN cluster is the
same for all three, so improve the prompt first, then re-compare. See
sub-project 2 in the spec.

## Report-only baseline (for setting floors later)

Gated model, synthetic: languages 0.857, experience 0.990, education
0.897, certifications 1.000. Real: 1.000 / 1.000 / 0.800 / 0.917. Floors
should be set from a second measurement after the prompt change, not from
this one.

## How to re-run

```
JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm
```

- `JOBIFY_PARSE_EVAL_MODELS=a,b,c` compares models in one run; the first
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
- Replace the tables above from the printed comparison and summaries and
  commit alongside whatever prompt, model, or dataset change prompted the
  re-run.
