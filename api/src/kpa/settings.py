"""Application settings, sourced from environment variables.

Settings are validated at startup; the app refuses to boot on invalid input.
"""

from __future__ import annotations

from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["local", "dev", "staging", "prod"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
LogFormat = Literal["text", "json"]


class Settings(BaseSettings):
    """Service-wide configuration.

    Backed by environment variables prefixed with `KPA_`.
    """

    model_config = SettingsConfigDict(
        env_prefix="KPA_",
        env_file=None,  # loaded explicitly via uv run --env-file in dev
        case_sensitive=False,
        extra="ignore",
    )

    env: Environment
    service_name: str
    log_level: LogLevel = "INFO"
    log_format: LogFormat = "text"
    db_url: str = Field(..., description="SQLAlchemy DSN; must use postgresql+asyncpg driver.")

    # --- Auth / JWT ---
    jwt_secret: str = Field(..., description="HS256 signing secret. Must be at least 32 bytes.")
    jwt_access_ttl_seconds: int = Field(
        default=600,
        gt=0,
        description="Access token lifetime in seconds.",
    )
    jwt_refresh_ttl_seconds: int = Field(
        default=2592000,
        gt=0,
        description="Refresh token lifetime in seconds (default 30 days).",
    )

    # --- Google OAuth ---
    google_oauth_client_ids: list[str] | str = Field(
        ...,
        description=(
            "CSV of accepted Google OAuth Client IDs (one per platform: web/iOS/Android)."
            " An ID token whose `aud` matches any of these is accepted."
        ),
    )
    google_jwks_url: str = Field(
        default="https://www.googleapis.com/oauth2/v3/certs",
        description="Override for tests + offline dev.",
    )
    google_jwks_cache_ttl_seconds: int = Field(
        default=3600,
        gt=0,
        description="In-process JWKS cache lifetime in seconds.",
    )

    # --- Auth policy ---
    auth_require_email_verified: bool = Field(
        default=False,
        description=(
            "When true, reject Google sign-ins with email_verified=false."
            " Off by default; flippable via env."
        ),
    )

    @field_validator("log_level", mode="before")
    @classmethod
    def _upper_log_level(cls, v: object) -> object:
        return v.upper() if isinstance(v, str) else v

    @field_validator("log_format", mode="before")
    @classmethod
    def _lower_log_format(cls, v: object) -> object:
        return v.lower() if isinstance(v, str) else v

    @field_validator("db_url")
    @classmethod
    def _enforce_async_driver(cls, v: str) -> str:
        if not v.startswith("postgresql+asyncpg://"):
            raise ValueError("db_url must use the postgresql+asyncpg:// driver")
        return v

    @field_validator("jwt_secret")
    @classmethod
    def _enforce_jwt_secret_length(cls, v: str) -> str:
        if len(v.encode("utf-8")) < 32:
            raise ValueError(
                "jwt_secret must be at least 32 bytes (use a cryptographically random secret)"
            )
        return v

    @field_validator("google_oauth_client_ids", mode="before")
    @classmethod
    def _split_google_client_ids(cls, v: object) -> object:
        """Same CSV-parsing behavior as allowed_resume_content_types."""
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v

    @field_validator("google_oauth_client_ids")
    @classmethod
    def _enforce_google_client_id_suffix(cls, v: list[str]) -> list[str]:
        if not v:
            raise ValueError("google_oauth_client_ids must contain at least one entry")
        bad = [x for x in v if not x.endswith(".apps.googleusercontent.com")]
        if bad:
            raise ValueError(
                "google_oauth_client_ids must end in .apps.googleusercontent.com;"
                f" bad entries: {bad}"
            )
        return v
