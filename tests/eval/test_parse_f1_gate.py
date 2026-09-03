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
    """Gate on JOBIFY_EVAL_GEMINI_API_KEY, NOT JOBIFY_GEMINI_API_KEY.

    ``tests/conftest.py`` hard-sets ``JOBIFY_GEMINI_API_KEY`` to a fake value
    to keep the suite hermetic, so checking it here would (a) always be truthy
    and (b) hand this lane the fake key. conftest copies the operator's real
    key to ``JOBIFY_EVAL_GEMINI_API_KEY`` when this lane is selected; its
    absence means no real key was exported, so skip rather than fail.
    """
    import os

    return os.environ.get("JOBIFY_PARSE_EVAL_PARSER") == "llm" and bool(
        os.environ.get("JOBIFY_EVAL_GEMINI_API_KEY")
    )


@pytest.mark.skipif(
    not _llm_lane_enabled(),
    reason="LLM lane: set JOBIFY_PARSE_EVAL_PARSER=llm + JOBIFY_GEMINI_API_KEY (never runs in CI)",
)
def test_llm_parser_meets_quality_gate() -> None:
    """On-demand lane — live Gemini via the interactive path. The committed
    ``core/data/parse_eval/LLM_EVAL_REPORT.md`` is the durable record; this
    test is the measurement.

    Run: JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm

    Calls the same `parse_text` the LIVE parse path uses, over the 20 gold
    examples. This lane originally routed through a `parse_texts_batch` Batch
    API path, added only because free-tier caps made 20 interactive calls
    infeasible. That path was never verified against the real API and has
    since been removed; measuring the interactive path is also strictly
    better, because the acceptance number then describes what production
    actually runs rather than a transport nothing else uses.
    """
    import asyncio
    import os

    from google import genai

    from jobify.eval.parse_f1 import DEFAULT_DATA_DIR, _load_examples
    from jobify.integrations.parser.base import LlmParserError, ParsedResume
    from jobify.integrations.parser.llm_parser import GeminiResumeParser

    client = genai.Client(api_key=os.environ["JOBIFY_EVAL_GEMINI_API_KEY"])
    parser = GeminiResumeParser(
        client=client,
        model=os.environ.get("JOBIFY_RESUME_PARSER_MODEL", "gemini-2.5-flash"),
    )

    examples = _load_examples(DEFAULT_DATA_DIR)
    texts = [text for _example_id, text, _expected in examples]

    # Paced sequentially to stay under the request-per-minute ceiling. MEASURED
    # free-tier limit for gemini-2.5-flash (2026-08-14, not the docs' number):
    # 20 requests per DAY -- exactly the size of the gold dataset, so the free
    # tier has ZERO margin and any retry pushes the run over. ~7s spacing keeps
    # the per-minute ceiling clear and runs the lane in ~2.5min; on a paid-tier
    # key set JOBIFY_PARSE_EVAL_DELAY_S=0 to run it flat out.
    delay_s = float(os.environ.get("JOBIFY_PARSE_EVAL_DELAY_S", "7"))

    def _is_retryable(exc: BaseException) -> bool:
        """Only back off on transient failures.

        `parse_text` flattens every API failure into `LlmParserError`, so the
        status code survives only on `__cause__`. Without this check a
        permanent error (403 project denied, 400 bad key) burned all three
        attempts plus 90s of backoff and buried its own cause -- which is
        precisely what made the 2026-08-14 project-denial slow to diagnose.
        """
        cause = exc.__cause__
        text = f"{type(cause).__name__}: {cause}" if cause else str(exc)
        if any(sig in text for sig in ("PERMISSION_DENIED", "INVALID_ARGUMENT", "NOT_FOUND")):
            return False
        # A 429 is two different failures wearing one status. The per-minute
        # ceiling is transient -- the pacing above is the primary defence and
        # retry is the net, so RESOURCE_EXHAUSTED on its own must stay
        # retryable. Depleted billing credits are permanent, and on 2026-09-03
        # that cost 93s of backoff before surfacing the real message. Match the
        # message body, not the status. Lowercased into its own name because the
        # ALL-CAPS signatures above are deliberately case-sensitive.
        lowered = text.lower()
        if any(sig in lowered for sig in ("prepayment credits", "credits are depleted")):
            return False
        return True

    async def _parse_one(text: str) -> ParsedResume:
        backoff = 30.0
        for attempt in range(3):
            try:
                return await parser.parse_text(text)
            except LlmParserError as exc:
                if attempt == 2 or not _is_retryable(exc):
                    cause = exc.__cause__
                    if cause is not None:
                        raise AssertionError(f"Gemini call failed: {cause}") from exc
                    raise
                await asyncio.sleep(backoff)
                backoff *= 2
        raise AssertionError("unreachable")

    async def _parse_all() -> list[ParsedResume]:
        out: list[ParsedResume] = []
        for index, text in enumerate(texts):
            if index:
                await asyncio.sleep(delay_s)
            out.append(await _parse_one(text))
        return out

    parsed_resumes = asyncio.run(_parse_all())
    results_by_text: dict[str, ParsedResume] = dict(zip(texts, parsed_resumes, strict=True))

    report = eval_gold_dataset(parse_fn=lambda t: results_by_text[t])

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
