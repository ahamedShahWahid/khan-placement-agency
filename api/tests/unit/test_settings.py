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
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv("KPA_GOOGLE_OAUTH_CLIENT_IDS", "test.apps.googleusercontent.com")

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
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv("KPA_GOOGLE_OAUTH_CLIENT_IDS", "test.apps.googleusercontent.com")

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
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv("KPA_GOOGLE_OAUTH_CLIENT_IDS", "test.apps.googleusercontent.com")

    settings = Settings()

    assert settings.log_level == "DEBUG"
    assert settings.log_format == "json"


def test_settings_loads_db_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv("KPA_GOOGLE_OAUTH_CLIENT_IDS", "test.apps.googleusercontent.com")

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


# ---------------------------------------------------------------------------
# Auth / JWT + Google OAuth settings
# ---------------------------------------------------------------------------


def _set_minimum_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set the minimum env vars required by Settings to construct successfully."""
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv(
        "KPA_GOOGLE_OAUTH_CLIENT_IDS",
        "abc.apps.googleusercontent.com",
    )


def test_jwt_secret_rejects_short_value(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 31)  # 31 bytes — one short
    monkeypatch.setenv(
        "KPA_GOOGLE_OAUTH_CLIENT_IDS",
        "abc.apps.googleusercontent.com",
    )
    with pytest.raises(ValidationError, match="jwt_secret must be at least 32"):
        Settings()


def test_jwt_secret_accepts_32_byte_value(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv(
        "KPA_GOOGLE_OAUTH_CLIENT_IDS",
        "abc.apps.googleusercontent.com",
    )
    s = Settings()
    assert s.jwt_secret == "x" * 32


def test_jwt_ttl_defaults(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    s = Settings()
    assert s.jwt_access_ttl_seconds == 600
    assert s.jwt_refresh_ttl_seconds == 2592000


def test_jwt_ttl_rejects_non_positive(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    monkeypatch.setenv("KPA_JWT_ACCESS_TTL_SECONDS", "0")
    with pytest.raises(ValidationError):
        Settings()


def test_google_oauth_client_ids_parses_csv(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    monkeypatch.setenv(
        "KPA_GOOGLE_OAUTH_CLIENT_IDS",
        "web.apps.googleusercontent.com , ios.apps.googleusercontent.com",
    )
    s = Settings()
    assert s.google_oauth_client_ids == [
        "web.apps.googleusercontent.com",
        "ios.apps.googleusercontent.com",
    ]


def test_google_oauth_client_ids_rejects_bad_suffix(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    monkeypatch.setenv("KPA_GOOGLE_OAUTH_CLIENT_IDS", "notagoogleclient.example.com")
    with pytest.raises(ValidationError, match="apps.googleusercontent.com"):
        Settings()


def test_google_jwks_url_default(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    s = Settings()
    assert s.google_jwks_url == "https://www.googleapis.com/oauth2/v3/certs"


def test_auth_require_email_verified_defaults_false(monkeypatch: pytest.MonkeyPatch) -> None:
    _set_minimum_env(monkeypatch)
    s = Settings()
    assert s.auth_require_email_verified is False
