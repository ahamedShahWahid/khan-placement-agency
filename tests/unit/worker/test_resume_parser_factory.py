"""get_resume_parser() selection matrix — no network, no real key."""

from __future__ import annotations

import os

import pytest
from pydantic import SecretStr

import jobify_worker.runtime as runtime_mod
from jobify.integrations.parser.fallback import FallbackResumeParser
from jobify.integrations.parser.library import LibraryResumeParser


@pytest.fixture(autouse=True)
def _reset_singleton(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(runtime_mod, "_resume_parser", None)
    yield
    monkeypatch.setattr(runtime_mod, "_resume_parser", None)


def test_library_selection(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "library")
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, LibraryResumeParser)


def test_llm_selection_with_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "llm")
    monkeypatch.setattr(runtime_mod.settings, "gemini_api_key", SecretStr("k"))
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, FallbackResumeParser)


def test_llm_without_key_degrades_to_library(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "llm")
    monkeypatch.setattr(runtime_mod.settings, "gemini_api_key", None)
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, LibraryResumeParser)


def test_singleton_cached(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "library")
    assert runtime_mod.get_resume_parser() is runtime_mod.get_resume_parser()


def test_test_env_resolves_to_library_parser() -> None:
    """Regression guard for the live-Gemini-calls-in-CI incident.

    ``tests/conftest.py`` sets ``JOBIFY_GEMINI_API_KEY`` to a fake value so
    other tests can exercise the "key present" branches without a real key —
    but that means ``resume_parser="llm"`` (the production default) would
    build a real ``genai.Client`` and attempt live HTTP against Gemini during
    the test suite. ``conftest.py`` also sets ``JOBIFY_RESUME_PARSER=library``
    as a default; this asserts that default actually lands on the settings
    object the factory reads, with NO monkeypatching of ``resume_parser``.
    """
    assert os.environ["JOBIFY_RESUME_PARSER"] == "library"
    assert runtime_mod.settings.resume_parser == "library"
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, LibraryResumeParser)
