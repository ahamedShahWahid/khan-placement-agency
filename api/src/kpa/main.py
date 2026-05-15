"""Uvicorn entrypoint.

Run locally:
    uv run uvicorn kpa.main:app --reload --port 8000
"""

from __future__ import annotations

from kpa.app_factory import create_app

app = create_app()
