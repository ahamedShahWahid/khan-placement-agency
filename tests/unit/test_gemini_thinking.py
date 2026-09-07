"""The "no thinking" knob differs by Gemini family — pin the mapping.

3.x rejects ``thinking_budget=0`` with 400 INVALID_ARGUMENT (probed
2026-09-07 on gemini-3.5-flash-lite); 2.x has no ``thinking_level``.
"""

from __future__ import annotations

import pytest
from google.genai import types

from jobify.integrations.gemini_thinking import gemini_major_version, no_thinking_config


@pytest.mark.parametrize(
    ("model", "major"),
    [
        ("gemini-2.5-flash", 2),
        ("gemini-2.5-flash-lite", 2),
        ("gemini-3.1-flash-lite", 3),
        ("gemini-3.5-flash-lite", 3),
        ("gemini-3.8-flash", 3),
        ("GEMINI-3.5-FLASH", 3),
        ("gemini-embedding-2", None),
        ("some-other-model", None),
    ],
)
def test_major_version_parsing(model: str, major: int | None) -> None:
    assert gemini_major_version(model) == major


def test_2x_uses_thinking_budget_zero() -> None:
    cfg = no_thinking_config("gemini-2.5-flash")
    assert cfg.thinking_budget == 0
    assert cfg.thinking_level is None


@pytest.mark.parametrize("model", ["gemini-3.1-flash-lite", "gemini-3.5-flash-lite"])
def test_3x_uses_thinking_level_minimal(model: str) -> None:
    cfg = no_thinking_config(model)
    assert cfg.thinking_budget is None
    assert cfg.thinking_level == types.ThinkingLevel.MINIMAL


def test_unknown_model_falls_back_to_2x_form() -> None:
    """Every model this codebase ran before 3.x existed took budget=0; an
    unrecognised id keeps that rather than guessing the newer knob."""
    cfg = no_thinking_config("mystery-model")
    assert cfg.thinking_budget == 0
