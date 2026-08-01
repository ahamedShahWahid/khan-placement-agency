"""get_resume_parser() selection matrix — no network, no real key."""

from __future__ import annotations

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
