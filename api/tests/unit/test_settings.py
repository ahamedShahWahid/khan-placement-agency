"""Tests for the Settings module."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from kpa.settings import Settings


def test_settings_loads_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")

    settings = Settings()

    assert settings.env == "local"
    assert settings.log_level == "DEBUG"
    assert settings.log_format == "text"
    assert settings.service_name == "kpa-api"


def test_settings_rejects_unknown_log_level(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_LOG_LEVEL", "VERBOSE")  # invalid
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")

    with pytest.raises(ValidationError):
        Settings()


def test_settings_rejects_unknown_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "uat")  # invalid
    monkeypatch.setenv("KPA_LOG_LEVEL", "INFO")
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")

    with pytest.raises(ValidationError):
        Settings()


def test_settings_defaults_when_optional_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    # Required vars only; optional vars take defaults.
    for k in ("KPA_LOG_LEVEL", "KPA_LOG_FORMAT"):
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")

    settings = Settings()

    assert settings.log_level == "INFO"
    assert settings.log_format == "text"
