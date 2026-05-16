"""Async SQLAlchemy session wiring.

Single-engine, single-schema (`kpa`). R/W routing is out of scope for this
plan — see IMPLEMENTATION_SPEC.md §5 for the eventual split design.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from kpa.settings import Settings

_SCHEMA = "kpa"


def create_engine_from_settings(settings: Settings | None = None) -> AsyncEngine:
    """Construct the application's async engine.

    Pool tuning is intentionally minimal here — production sizing happens via
    env vars in a later plan once we have load-test data.
    """
    settings = settings or Settings()
    return create_async_engine(
        settings.db_url,
        echo=False,
        pool_pre_ping=True,
        connect_args={"server_settings": {"search_path": _SCHEMA}},
    )


def make_sessionmaker(engine: AsyncEngine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(
        bind=engine,
        expire_on_commit=False,
        autoflush=False,
    )


async def get_session(
    sm: async_sessionmaker[AsyncSession],
) -> AsyncIterator[AsyncSession]:
    """FastAPI dependency: yield a session, close on exit, rollback on error."""
    async with sm() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
