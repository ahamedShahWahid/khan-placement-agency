"""Integration tests for PATCH /v1/applicants/me."""

from __future__ import annotations

import httpx
import pytest
from sqlalchemy import select

from kpa.auth.google_verifier import GoogleClaims
from kpa.db.models import Applicant

pytestmark = pytest.mark.integration


def _claims() -> GoogleClaims:
    return GoogleClaims(
        sub="google-sub-profile",
        iss="https://accounts.google.com",
        aud="test.apps.googleusercontent.com",
        email="alice@example.com",
        email_verified=True,
        name="Alice",
    )


async def _signin(client: httpx.AsyncClient, google_verifier) -> dict:
    google_verifier.canned["tok"] = _claims()
    resp = await client.post("/v1/auth/oauth/google", json={"id_token": "tok"})
    assert resp.status_code == 200
    return resp.json()


async def test_patch_partial_update(
    async_client: httpx.AsyncClient, google_verifier, session
) -> None:
    signin = await _signin(async_client, google_verifier)
    access = signin["access_token"]

    resp = await async_client.patch(
        "/v1/applicants/me",
        headers={"Authorization": f"Bearer {access}"},
        json={"locations": ["Pune", "Bengaluru"], "expected_ctc": 1800000},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["applicant"]["locations"] == ["Pune", "Bengaluru"]
    assert body["applicant"]["expected_ctc"] == "1800000.00"
    assert body["applicant"]["full_name"] == "Alice"

    row = (
        await session.execute(
            select(Applicant).where(Applicant.user_id == signin["user"]["id"])
        )
    ).scalar_one()
    assert row.locations == ["Pune", "Bengaluru"]
