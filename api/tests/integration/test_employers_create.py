from __future__ import annotations

import pytest
from sqlalchemy import select

from kpa.db.models import EmployerUser, User, UserRole

pytestmark = pytest.mark.integration


async def test_create_employer_happy_path_flips_role(
    async_client, session, applicant_user_and_token
):
    """Sign-in defaulted role=APPLICANT; POST /v1/employers flips it to RECRUITER."""
    user, token = applicant_user_and_token

    resp = await async_client.post(
        "/v1/employers",
        json={"name": "Acme Corp", "gst": "29ABCDE1234F1Z5"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["name"] == "Acme Corp"
    assert body["gst"] == "29ABCDE1234F1Z5"
    assert body["verified_at"] is None

    # Side effect: user.role flipped to RECRUITER
    refreshed_role = await session.scalar(select(User.role).where(User.id == user.id))
    assert refreshed_role == UserRole.RECRUITER

    link = await session.scalar(
        select(EmployerUser.id).where(
            EmployerUser.user_id == user.id,
            EmployerUser.deleted_at.is_(None),
        )
    )
    assert link is not None
