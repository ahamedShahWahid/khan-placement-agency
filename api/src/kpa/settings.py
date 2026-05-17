"""Application settings, sourced from environment variables.

Settings are validated at startup; the app refuses to boot on invalid input.
"""

from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Environment = Literal["local", "dev", "staging", "prod"]
LogLevel = Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
LogFormat = Literal["text", "json"]


_DEFAULT_ALLOWED_RESUME_CONTENT_TYPES = [
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]


class Settings(BaseSettings):
    """Service-wide configuration.

    Backed by environment variables prefixed with ``KPA_``.
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
    storage_root: Path = Field(
        default=Path("var/uploads"),
        description=(
            "Filesystem root for LocalFileStorage." " Relative paths resolve against the API's CWD."
        ),
    )
    max_upload_bytes: int = Field(
        default=10 * 1024 * 1024,
        description="Max bytes accepted for an uploaded file (per request).",
    )
    allowed_resume_content_types: list[str] | str = Field(
        default_factory=lambda: list(_DEFAULT_ALLOWED_RESUME_CONTENT_TYPES),
        description="Whitelist of Content-Type values accepted by the resume upload route.",
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

    @field_validator("allowed_resume_content_types", mode="before")
    @classmethod
    def _split_csv(cls, v: object) -> object:
        """Parse comma-separated env strings into list[str].

        Pydantic-settings defaults to JSON parsing for list fields, which
        would force users to write KPA_ALLOWED_RESUME_CONTENT_TYPES='["a","b"]'.
        A CSV split keeps the env-var format ergonomic.
        """
        if isinstance(v, str):
            return [item.strip() for item in v.split(",") if item.strip()]
        return v
