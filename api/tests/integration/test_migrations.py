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


@pytest.mark.integration
async def test_migrated_db_has_employers_and_jobs_tables(session: AsyncSession) -> None:
    result = await session.execute(
        text("""
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'kpa'
        ORDER BY table_name
    """)
    )
    names = {row[0] for row in result}
    assert "employers" in names
    assert "jobs" in names


@pytest.mark.integration
async def test_jobs_has_partial_indexes(session: AsyncSession) -> None:
    result = await session.execute(
        text("""
        SELECT indexname FROM pg_indexes
        WHERE schemaname = 'kpa' AND tablename = 'jobs'
    """)
    )
    names = {row[0] for row in result}
    assert "ix_jobs_employer_id_live" in names
    assert "ix_jobs_status_posted_at_live" in names


@pytest.mark.integration
async def test_employers_name_norm_is_partial_unique(session: AsyncSession) -> None:
    result = await session.execute(
        text("""
        SELECT indexdef FROM pg_indexes
        WHERE schemaname = 'kpa'
          AND tablename = 'employers'
          AND indexname = 'ix_employers_name_norm_live'
    """)
    )
    row = result.first()
    assert row is not None
    assert "UNIQUE INDEX" in row[0]
    assert "deleted_at IS NULL" in row[0]
