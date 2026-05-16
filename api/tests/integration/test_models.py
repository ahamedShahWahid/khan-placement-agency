"""CRUD + invariants on User and Applicant models."""

from __future__ import annotations

from datetime import UTC, datetime

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from kpa.db.models import Applicant, User, UserRole


@pytest.mark.integration
async def test_create_user_and_applicant(session: AsyncSession) -> None:
    user = User(email="a@example.com", role=UserRole.APPLICANT)
    session.add(user)
    await session.flush()
    applicant = Applicant(user_id=user.id, full_name="A. Test", locations=["Bengaluru", "Pune"])
    session.add(applicant)
    await session.commit()

    loaded = (
        await session.execute(select(Applicant).where(Applicant.user_id == user.id))
    ).scalar_one()
    assert loaded.full_name == "A. Test"
    assert loaded.locations == ["Bengaluru", "Pune"]


@pytest.mark.integration
async def test_cascade_delete_user_deletes_applicant(session: AsyncSession) -> None:
    user = User(email="b@example.com", role=UserRole.APPLICANT)
    session.add(user)
    await session.flush()
    session.add(Applicant(user_id=user.id, full_name="B. Test"))
    await session.commit()

    await session.delete(user)
    await session.commit()

    remaining = (await session.execute(select(Applicant).where(Applicant.user_id == user.id))).all()
    assert remaining == []


@pytest.mark.integration
async def test_soft_delete_via_deleted_at(session: AsyncSession) -> None:
    user = User(email="c@example.com", role=UserRole.APPLICANT)
    session.add(user)
    await session.commit()

    user.deleted_at = datetime.now(UTC)
    await session.commit()

    # Row still exists; only the column is set.
    refreshed = (await session.execute(select(User).where(User.id == user.id))).scalar_one()
    assert refreshed.deleted_at is not None


@pytest.mark.integration
async def test_unique_email_constraint(session: AsyncSession) -> None:
    session.add(User(email="dup@example.com", role=UserRole.APPLICANT))
    await session.commit()
    session.add(User(email="dup@example.com", role=UserRole.APPLICANT))
    with pytest.raises(IntegrityError):
        await session.commit()
    await session.rollback()
