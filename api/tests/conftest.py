"""Shared test fixtures."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from kpa.app_factory import create_app


@pytest.fixture
def client(monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    """A TestClient bound to a freshly created app with deterministic settings."""

    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_LOG_LEVEL", "INFO")
    monkeypatch.setenv("KPA_LOG_FORMAT", "text")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")
    monkeypatch.setenv("KPA_JWT_SECRET", "x" * 32)
    monkeypatch.setenv(
        "KPA_GOOGLE_OAUTH_CLIENT_IDS",
        "test.apps.googleusercontent.com",
    )

    app = create_app()
    with TestClient(app) as c:
        yield c
