"""Parse F1 quality gate (spec §13 P1).

Runs the eval harness against the gold dataset in ``api/data/parse_eval/``
and asserts the parser stays above the per-field floors AND the overall
target. Print full breakdown on failure to make diagnosis cheap.

Gate config:
- Overall macro-F1 >= 0.85 (spec P2 target; ratchet to 0.90 before launch).
- Per-field floors: email 0.95, phone 0.85, name 0.70, skills 0.75.

Marked ``@pytest.mark.eval`` so it runs only when explicitly requested:
``uv run pytest -m eval``. CI runs this separately from the unit + integration
suites.
"""

from __future__ import annotations

import pytest

from jobify.eval.parse_f1 import eval_gold_dataset

pytestmark = pytest.mark.eval


# Per-field minimum F1 — tune downward only with justification, never upward
# silently. The overall gate is the load-bearing one for spec compliance.
PER_FIELD_FLOORS: dict[str, float] = {
    "email": 0.95,
    "phone": 0.85,
    "name": 0.70,
    "skills": 0.75,
}

OVERALL_FLOOR = 0.85


def test_library_parser_meets_quality_gate() -> None:
    report = eval_gold_dataset()

    # Always print the summary — pytest captures stdout on pass but prints
    # it on fail. Running with -s shows it both ways.
    print()
    print(report.summary())
    print()
    print(report.example_breakdown())

    failures: list[str] = []

    for field_name, floor in PER_FIELD_FLOORS.items():
        f1 = report.per_field_f1[field_name]
        if f1 < floor:
            failures.append(f"{field_name}: F1={f1:.3f} below floor {floor}")

    if report.overall_f1 < OVERALL_FLOOR:
        failures.append(f"overall: F1={report.overall_f1:.3f} below floor {OVERALL_FLOOR}")

    assert not failures, "Parse F1 gate violated:\n  " + "\n  ".join(failures)


LLM_OVERALL_FLOOR = 0.90


def _llm_lane_enabled() -> bool:
    import os

    return os.environ.get("JOBIFY_PARSE_EVAL_PARSER") == "llm" and bool(
        os.environ.get("JOBIFY_GEMINI_API_KEY")
    )


@pytest.mark.skipif(
    not _llm_lane_enabled(),
    reason="LLM lane: set JOBIFY_PARSE_EVAL_PARSER=llm + JOBIFY_GEMINI_API_KEY (never runs in CI)",
)
def test_llm_parser_meets_quality_gate() -> None:
    """On-demand lane — live Gemini. The committed LLM_EVAL_REPORT.md is the
    durable record; this test is the measurement.

    Run: JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s
    """
    import asyncio
    import os

    from google import genai

    from jobify.integrations.parser.llm_parser import GeminiResumeParser

    client = genai.Client(api_key=os.environ["JOBIFY_GEMINI_API_KEY"])
    parser = GeminiResumeParser(
        client=client,
        model=os.environ.get("JOBIFY_RESUME_PARSER_MODEL", "gemini-2.5-flash"),
    )

    report = eval_gold_dataset(parse_fn=lambda text: asyncio.run(parser.parse_text(text)))

    print()
    print(report.summary())
    print()
    print(report.example_breakdown())

    failures: list[str] = []
    for field_name, floor in PER_FIELD_FLOORS.items():
        f1 = report.per_field_f1[field_name]
        if f1 < floor:
            failures.append(f"{field_name}: F1={f1:.3f} below floor {floor}")
    if report.overall_f1 < LLM_OVERALL_FLOOR:
        failures.append(f"overall: F1={report.overall_f1:.3f} below LLM floor {LLM_OVERALL_FLOOR}")
    assert not failures, "LLM parse F1 gate violated:\n  " + "\n  ".join(failures)
