"""Per-model-family "no thinking" config for Gemini generate_content calls.

Both LLM call sites (resume parser, match explainer) are extraction /
two-sentence JSON tasks where thinking buys nothing and its tokens count
against ``max_output_tokens`` (the explainer's 200-token cap was once starved
to an unparsable preamble by ~190 thought tokens).

The knob differs by family: 2.x accepts ``thinking_budget=0``; 3.x rejects it
with ``400 INVALID_ARGUMENT`` (probed 2026-09-07 against gemini-3.5-flash-lite)
and wants ``thinking_level="minimal"`` instead. Pick by the model id's major
version so switching models stays a settings change.
"""

from __future__ import annotations

import re
from typing import Final

from google.genai import types

_MAJOR_VERSION: Final[re.Pattern[str]] = re.compile(r"^gemini-(\d+)(?:\.\d+)?")


def gemini_major_version(model: str) -> int | None:
    """``"gemini-3.5-flash-lite"`` → 3; ``"gemini-2.5-flash"`` → 2; unknown → None."""
    match = _MAJOR_VERSION.match(model.strip().lower())
    return int(match.group(1)) if match else None


def no_thinking_config(model: str) -> types.ThinkingConfig:
    """The ThinkingConfig that disables thinking for ``model``'s family.

    Unknown ids fall back to the 2.x form, which is what every model this
    codebase ran before 3.x existed.
    """
    major = gemini_major_version(model)
    if major is not None and major >= 3:
        return types.ThinkingConfig(thinking_level=types.ThinkingLevel.MINIMAL)
    return types.ThinkingConfig(thinking_budget=0)
