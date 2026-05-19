"""Integration test for upload-route resilience when the Celery broker is down."""

from __future__ import annotations

import io

import pytest
from fpdf import FPDF
from sqlalchemy import select

from kpa.db.models import Applicant, Resume, ResumeParseStatus, User, UserRole

pytestmark = pytest.mark.integration


def _tiny_pdf() -> bytes:
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Helvetica", size=12)
    pdf.cell(text="resume content")
    return bytes(pdf.output())


async def _make_applicant(session) -> str:
    user = User(email="dispatch@ex.com", role=UserRole.APPLICANT)
    session.add(user)
    await session.flush()
    applicant = Applicant(user_id=user.id, full_name="Dispatch Test")
    session.add(applicant)
    await session.commit()
    return str(applicant.id)


async def test_upload_returns_201_even_if_broker_dispatch_raises(
    async_client,
    session,
    monkeypatch,
) -> None:
    """If parse_resume.delay() raises (broker down), upload still returns 201
    and the row exists with parse_status=pending."""
    from kpa.workers.tasks import parse as parse_module

    def _raise_broker_down(*args, **kwargs):  # type: ignore[no-untyped-def]
        raise ConnectionError("broker unreachable")

    monkeypatch.setattr(parse_module.parse_resume, "delay", _raise_broker_down)

    applicant_id = await _make_applicant(session)
    pdf = _tiny_pdf()

    resp = await async_client.post(
        f"/v1/applicants/{applicant_id}/resumes",
        files={"file": ("cv.pdf", io.BytesIO(pdf), "application/pdf")},
    )

    assert resp.status_code == 201
    row = (
        await session.execute(
            select(Resume).where(Resume.applicant_id.in_([applicant_id]))
        )
    ).scalar_one()
    assert row.parse_status == ResumeParseStatus.PENDING
