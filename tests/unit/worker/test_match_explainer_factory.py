"""get_match_explainer() selection matrix — no network, no real key.

Sibling to test_resume_parser_factory.py's regression guard for the same
live-Gemini-calls-in-CI incident.
"""

from __future__ import annotations

import os

import pytest

import jobify_worker.runtime as runtime_mod
from jobify.scoring.explainer import TemplatedExplainer


@pytest.fixture(autouse=True)
def _reset_singleton(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(runtime_mod, "_match_explainer", None)
    yield
    monkeypatch.setattr(runtime_mod, "_match_explainer", None)


def test_test_env_resolves_to_templated_explainer() -> None:
    """Regression guard for the live-Gemini-calls-in-CI incident.

    ``tests/conftest.py`` hard-sets ``JOBIFY_GEMINI_API_KEY`` to a fake value
    so other tests can exercise the "key present" branches without a real
    key — but that means ``match_explainer="llm"`` (the production default)
    would build a real ``genai.Client`` and attempt live HTTP against Gemini
    during the test suite. ``conftest.py`` also hard-sets
    ``JOBIFY_MATCH_EXPLAINER=templated``; this asserts that value actually
    lands on the settings object the factory reads, with NO monkeypatching
    of ``match_explainer``, and that a real ``JOBIFY_GEMINI_API_KEY`` sitting
    in the developer's shell can never override it (conftest hard-sets, not
    ``setdefault``).
    """
    assert os.environ["JOBIFY_MATCH_EXPLAINER"] == "templated"
    assert runtime_mod.settings.match_explainer == "templated"
    explainer = runtime_mod.get_match_explainer()
    assert isinstance(explainer, TemplatedExplainer)
