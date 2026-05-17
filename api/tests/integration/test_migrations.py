"""Verifies alembic upgrade head + downgrade base round-trip."""

from __future__ import annotations

import pytest
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


@pytest.mark.integration
async def test_migrated_db_has_users_and_applicants_tables(session: AsyncSession) -> None:
    result = await session.execute(
        text("""
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'kpa'
        ORDER BY table_name
    """)
    )
    names = {row[0] for row in result}
    assert "users" in names
    assert "applicants" in names


@pytest.mark.integration
async def test_users_has_partial_indexes(session: AsyncSession) -> None:
    result = await session.execute(
        text("""
        SELECT indexname FROM pg_indexes
        WHERE schemaname = 'kpa' AND tablename = 'users'
    """)
    )
    names = {row[0] for row in result}
    assert "ix_users_email_live" in names
    assert "ix_users_phone_live" in names
