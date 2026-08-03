"""Unit tests for the ExplainContext + TemplatedExplainer."""

from __future__ import annotations

from dataclasses import FrozenInstanceError
from decimal import Decimal

import pytest

from jobify.scoring.explain import templated_explanation
from jobify.scoring.explainer import ExplainContext, TemplatedExplainer, _templated_from_ctx


def _ctx(**overrides: object) -> ExplainContext:
    base: dict[str, object] = {
        "components": {"location": 1.0, "exp": 1.0, "ctc": 1.0},
        "vector": 0.9,
        "structured": 1.0,
        "total": 0.94,
        "threshold": 0.55,
        "job_title": "Senior Backend Engineer",
        "job_locations": ["Bangalore"],
        "job_min_exp_years": 5,
        "job_max_exp_years": 9,
        "job_ctc_max": Decimal("4200000"),
        "employer_name": "Acme",
        "applicant_expected_ctc": Decimal("3000000"),
        "applicant_locations": ["Bangalore"],
    }
    base.update(overrides)
    return ExplainContext(**base)  # type: ignore[arg-type]


@pytest.mark.asyncio
async def test_templated_explainer_matches_pure_function() -> None:
    """TemplatedExplainer.explain(ctx) must return exactly what
    templated_explanation(**fields) returns for the same fields."""
    ctx = _ctx()
    expected = templated_explanation(
        components=ctx.components,
        vector=ctx.vector,
        structured=ctx.structured,
        total=ctx.total,
        threshold=ctx.threshold,
        job_title=ctx.job_title,
        job_locations=ctx.job_locations,
        job_min_exp_years=ctx.job_min_exp_years,
        job_max_exp_years=ctx.job_max_exp_years,
        job_ctc_max=ctx.job_ctc_max,
        employer_name=ctx.employer_name,
        applicant_expected_ctc=ctx.applicant_expected_ctc,
        applicant_locations=ctx.applicant_locations,
    )
    out = await TemplatedExplainer().explain(ctx)
    assert out == expected
    assert out["generator"] == "templated"
    assert out["generator_version"] == "1"


def test_explain_context_is_frozen() -> None:
    """ExplainContext is a frozen dataclass — mutation must raise."""
    ctx = _ctx()
    with pytest.raises(FrozenInstanceError):
        ctx.total = 0.1  # type: ignore[misc]


def test_templated_explanation_hindi() -> None:
    ctx = _ctx(language="hi")  # the file's existing builder, with the new field
    result = _templated_from_ctx(ctx)
    assert result["generator"] == "templated"
    # Hindi fit text is Devanagari — assert script, not exact copy.
    assert any("ऀ" <= ch <= "ॿ" for ch in result["fit"])


def test_templated_explanation_hindi_caveat() -> None:
    """Caveat path is separate from fit — exercise it too (weak exp -> exp caveat)."""
    ctx = _ctx(
        language="hi",
        components={"location": 1.0, "exp": 0.4, "ctc": 1.0},
    )
    result = _templated_from_ctx(ctx)
    assert any("ऀ" <= ch <= "ॿ" for ch in result["caveat"])
    # {}-slots must survive .format() in the Hindi string.
    assert "5-9" in result["caveat"]


def test_templated_explanation_default_language_unchanged() -> None:
    ctx = _ctx()  # no language arg -> "en" default
    result = _templated_from_ctx(ctx)
    assert not any("ऀ" <= ch <= "ॿ" for ch in result["fit"])
