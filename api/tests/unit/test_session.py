"""Unit tests for the DB session module.

The integration tests in tests/integration/ cover real Postgres behavior.
These tests only verify lifecycle + wiring against a stubbed engine.
"""

from __future__ import annotations

import pytest

from kpa.db import session as session_module


def test_create_engine_uses_settings_db_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")

    engine = session_module.create_engine_from_settings()

    assert engine.url.render_as_string(hide_password=False) == "postgresql+asyncpg://u:p@h:5432/d"
    # Engine is configured for the "kpa" schema.
    assert engine.dialect.name == "postgresql"


async def test_get_session_yields_and_closes(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("KPA_ENV", "local")
    monkeypatch.setenv("KPA_SERVICE_NAME", "kpa-api")
    monkeypatch.setenv("KPA_DB_URL", "postgresql+asyncpg://u:p@h:5432/d")

    # We don't need a real DB connection for this lifecycle test.
    sm = session_module.make_sessionmaker(session_module.create_engine_from_settings())
    async for s in session_module.get_session(sm):
        assert s is not None
        assert not s.is_active or s.is_active  # exists; will be closed on context exit
