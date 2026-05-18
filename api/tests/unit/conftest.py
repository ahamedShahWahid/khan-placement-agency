"""Unit-test conftest.

Sets minimal environment variables so that modules that call ``Settings()`` at
import time (e.g. ``kpa.workers.celery_app``) can be collected by pytest
without a real service environment.

These defaults are overridden by the ``KPA_*`` variables already present in
the shell (e.g. when CI or a developer sets ``KPA_DB_URL``), so they never
shadow real values.
"""

from __future__ import annotations

import os


def pytest_configure(config: object) -> None:
    """Set env-var defaults before pytest collects and imports test modules.

    ``monkeypatch`` runs *after* collection, so module-level ``Settings()``
    calls need the vars to exist earlier.  ``os.environ.setdefault`` is safe:
    it only writes a value when the key is absent.
    """
    os.environ.setdefault("KPA_ENV", "local")
    os.environ.setdefault("KPA_SERVICE_NAME", "kpa-api")
    os.environ.setdefault(
        "KPA_DB_URL", "postgresql+asyncpg://kpa:kpa@localhost:5432/kpa_test"
    )
    os.environ.setdefault("KPA_REDIS_URL", "redis://localhost:6379/0")
