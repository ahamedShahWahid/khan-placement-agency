"""Tests for the Settings module."""

from __future__ import annotations

from pathlib import Path

import pytest
from pydantic import ValidationError

from kpa.settings import Settings


def test_settings_loads_from_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_LOG_LEVEL", "DEBUG")
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    settings = Settings()

    assert settings.env == "local"
    assert settings.log_level == "DEBUG"
    assert settings.log_format == "text"
    assert settings.service_name == "kpa-api"
    assert str(settings.db_url) == "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa"


def test_settings_rejects_unknown_log_level(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_LOG_LEVEL", "VERBOSE")  # invalid
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    with pytest.raises(ValidationError):
        Settings()


def test_settings_rejects_unknown_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "uat")  # invalid
    monkeypatch.setenv("KPA_LOG_LEVEL", "INFO")
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    with pytest.raises(ValidationError):
        Settings()


def test_settings_defaults_when_optional_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    # Required vars only; optional vars take defaults.
    for k in ("KPA_LOG_LEVEL", "KPA_LOG_FORMAT"):
        monkeypatch.delenv(k, raising=False)
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    settings = Settings()

    assert settings.log_level == "INFO"
    assert settings.log_format == "text"


def test_settings_raises_when_required_vars_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("KPA_ENV", raising=False)
    monkeypatch.delenv("KPA_SERVICE_NAME", raising=False)
    monkeypatch.delenv("KPA_LOG_LEVEL", raising=False)
    monkeypatch.delenv("KPA_LOG_FORMAT", raising=False)
    monkeypatch.delenv("KPA_DB_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings()


def test_settings_normalizes_log_level_case(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_LOG_LEVEL", "debug")  # lowercase
    monkeypatch.setenv("KPA_LOG_FORMAT", "JSON")  # uppercase
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    settings = Settings()

    assert settings.log_level == "DEBUG"
    assert settings.log_format == "json"


def test_settings_loads_db_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")

    settings = Settings()

    assert str(settings.db_url) == "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa"


def test_settings_rejects_missing_db_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.delenv("KPA_DB_URL", raising=False)

    with pytest.raises(ValidationError):
        Settings()


def test_settings_rejects_db_url_with_wrong_driver(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    # Sync driver — must be rejected since the runtime is async-only.
    monkeypatch.setenv("KPA_DB_URL", "postgresql://kpa:kpa@localhost:5432/kpa")

    with pytest.raises(ValidationError):
        Settings()


def test_settings_storage_root_defaults_to_var_uploads(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.delenv("KPA_STORAGE_ROOT", raising=False)

    settings = Settings()

    assert settings.storage_root == Path("var/uploads")


def test_settings_storage_root_honors_override(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.setenv("KPA_STORAGE_ROOT", str(tmp_path))

    settings = Settings()

    assert settings.storage_root == tmp_path


def test_settings_max_upload_bytes_defaults_to_10mb(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.delenv("KPA_MAX_UPLOAD_BYTES", raising=False)

    settings = Settings()

    assert settings.max_upload_bytes == 10 * 1024 * 1024


def test_settings_allowed_resume_content_types_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.delenv("KPA_ALLOWED_RESUME_CONTENT_TYPES", raising=False)

    settings = Settings()

    assert settings.allowed_resume_content_types == [
        "application/pdf",
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ]


def test_settings_allowed_resume_content_types_parses_csv(monkeypatch: pytest.MonkeyPatch) -> None:
    """Pydantic settings parses comma-separated strings into list[str] for env-var input."""
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.setenv("KPA_ALLOWED_RESUME_CONTENT_TYPES", "application/pdf,text/plain")

    settings = Settings()

    assert settings.allowed_resume_content_types == ["application/pdf", "text/plain"]
