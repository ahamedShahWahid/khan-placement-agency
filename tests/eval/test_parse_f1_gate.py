"""Parse F1 quality gate (spec §13 P1).

Runs the eval harness against the gold dataset in ``core/data/parse_eval/``
and asserts the parser stays above the per-field floors AND the overall
target. Print full breakdown on failure to make diagnosis cheap.

Gate config:
- Overall macro-F1 >= 0.85 for the library parser (CI). The 0.90 launch
  target is the LLM lane's floor (``LLM_OVERALL_FLOOR``), measured on demand.
- Per-field floors: email 0.95, phone 0.85, name 0.70, skills 0.75.
- Report-only fields (languages, experience, education, certifications) are
  printed by both lanes and gate nothing until a measured baseline exists.

Marked ``@pytest.mark.eval`` so it runs only when explicitly requested:
``uv run pytest -m eval``. CI runs this separately from the unit + integration
suites.

Real set: when ``sample_resume/`` exists locally (gitignored — real
applicants), both lanes also score it and print AGGREGATE COUNTS ONLY.
"""

from __future__ import annotations

import pytest

from jobify.eval.parse_f1 import (
    EvalReport,
    eval_examples,
    eval_gold_dataset,
    real_examples,
)

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
LLM_OVERALL_FLOOR = 0.90


def _gate_failures(report: EvalReport, overall_floor: float) -> list[str]:
    failures: list[str] = []
    for field_name, floor in PER_FIELD_FLOORS.items():
        f1 = report.per_field_f1[field_name]
        if f1 < floor:
            failures.append(f"{field_name}: F1={f1:.3f} below floor {floor}")
    if report.overall_f1 < overall_floor:
        failures.append(f"overall: F1={report.overall_f1:.3f} below floor {overall_floor}")
    return failures


def test_library_parser_meets_quality_gate() -> None:
    report = eval_gold_dataset()

    # Always print the summary — pytest captures stdout on pass but prints
    # it on fail. Running with -s shows it both ways.
    print()
    print(report.summary())
    print()
    print(report.example_breakdown())

    real = real_examples()
    if real:
        from jobify.eval.parse_f1 import _parse_text_only

        print()
        print(eval_examples(real, _parse_text_only, label="real set (local only)").summary())

    failures = _gate_failures(report, OVERALL_FLOOR)
    assert not failures, "Parse F1 gate violated:\n  " + "\n  ".join(failures)


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


def _llm_models() -> list[str]:
    """``JOBIFY_PARSE_EVAL_MODELS=a,b,c`` compares models in one run; the
    FIRST is the one the gate applies to (default: the production model)."""
    import os

    raw = os.environ.get("JOBIFY_PARSE_EVAL_MODELS")
    if raw:
        return [m.strip() for m in raw.split(",") if m.strip()]
    return [os.environ.get("JOBIFY_RESUME_PARSER_MODEL", "gemini-2.5-flash")]


@pytest.mark.skipif(
    not _llm_lane_enabled(),
    reason="LLM lane: set JOBIFY_PARSE_EVAL_PARSER=llm + JOBIFY_GEMINI_API_KEY (never runs in CI)",
)
def test_llm_parser_meets_quality_gate() -> None:
    """On-demand lane — live Gemini via the interactive path. The committed
    ``core/data/parse_eval/LLM_EVAL_REPORT.md`` is the durable record; this
    test is the measurement.

    Run: JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm
    Compare models: add JOBIFY_PARSE_EVAL_MODELS=gemini-2.5-flash,gemini-3.1-flash-lite
    Paid-tier key: add JOBIFY_PARSE_EVAL_DELAY_S=0

    Calls the same `parse_text` the LIVE parse path uses, over the synthetic
    gold examples and (when present locally) the real set. The gate applies to
    the first model on the synthetic set only; everything else is printed for
    comparison. Batch API was removed 2026-08-15 — measuring the interactive
    path is what production actually runs.
    """
    import asyncio
    import os

    from google import genai

    from jobify.eval.parse_f1 import DEFAULT_DATA_DIR, Example, _load_examples
    from jobify.integrations.parser.base import LlmParserError, ParsedResume
    from jobify.integrations.parser.llm_parser import GeminiResumeParser

    client = genai.Client(api_key=os.environ["JOBIFY_EVAL_GEMINI_API_KEY"])
    models = _llm_models()

    synthetic = _load_examples(DEFAULT_DATA_DIR)
    real = real_examples()

    # Paced sequentially to stay under the request-per-minute ceiling. MEASURED
    # free-tier limit for gemini-2.5-flash (2026-08-14, not the docs' number):
    # 20 requests per DAY -- exactly the size of the gold dataset, so the free
    # tier has ZERO margin and any retry pushes the run over. ~7s spacing keeps
    # the per-minute ceiling clear; on a paid-tier key set
    # JOBIFY_PARSE_EVAL_DELAY_S=0 to run it flat out.
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

    retries = 0

    async def _parse_one(parser: GeminiResumeParser, text: str) -> ParsedResume:
        nonlocal retries
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
                retries += 1
                await asyncio.sleep(backoff)
                backoff *= 2
        raise AssertionError("unreachable")

    async def _parse_all(parser: GeminiResumeParser, examples: list[Example]) -> list[ParsedResume]:
        out: list[ParsedResume] = []
        for index, (_example_id, text, _expected) in enumerate(examples):
            if index:
                await asyncio.sleep(delay_s)
            out.append(await _parse_one(parser, text))
        return out

    async def _run_model(model: str) -> dict[str, EvalReport]:
        parser = GeminiResumeParser(client=client, model=model)
        reports: dict[str, EvalReport] = {}
        for label, examples in (("synthetic gold", synthetic), ("real set (local only)", real)):
            if not examples:
                continue
            parsed = await _parse_all(parser, examples)
            by_text = dict(zip((t for _, t, _ in examples), parsed, strict=True))
            reports[label] = eval_examples(examples, lambda t, _m=by_text: _m[t], label=label)
        return reports

    async def _run_all() -> dict[str, dict[str, EvalReport]]:
        return {model: await _run_model(model) for model in models}

    results = asyncio.run(_run_all())

    for model, reports in results.items():
        print()
        print(f"=== {model} ===")
        for label, report in reports.items():
            print(report.summary())
            if label == "synthetic gold":
                print()
                print(report.example_breakdown())
                print()
                # Counts alone can't distinguish "the model invented a skill"
                # (the one error class this gate exists to catch) from "the
                # gold file omits a token the resume really contains", and the
                # model's output is not deterministic, so a re-call can't
                # reconstruct what a gated run saw. Synthetic set only.
                print(report.token_diff())
            print()
    print(f"Retries: {retries}")

    if len(models) > 1 or real:
        print()
        print("Comparison (F1 per field; first model is gated):")
        header = f"{'model':<24} {'set':<22} " + " ".join(f"{f[:8]:>8}" for f in _field_order())
        print(header + f" {'overall':>8}")
        for model, reports in results.items():
            for label, report in reports.items():
                cells = " ".join(f"{report.per_field_f1[f]:>8.3f}" for f in _field_order())
                print(f"{model:<24} {label:<22} {cells} {report.overall_f1:>8.3f}")

    gated = results[models[0]]["synthetic gold"]
    failures = _gate_failures(gated, LLM_OVERALL_FLOOR)
    assert not failures, "LLM parse F1 gate violated:\n  " + "\n  ".join(failures)


def _field_order() -> tuple[str, ...]:
    from jobify.eval.parse_f1 import ALL_FIELDS

    return ALL_FIELDS
