"""DSR export builder — DPDP § 11 right-of-access.

Exports:
    UserExport      — Pydantic v2 envelope model (18 top-level fields).
    build_user_export — async read-only assembly function.

This module does NOT write audit rows. The route handler (routes/dsr.py)
writes user.dsr_export_requested and user.dsr_export_completed around this
call so the request row is durable even if assembly fails.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from kpa.db.models import (
    Applicant,
    ApplicantEmbedding,
    Application,
    AuditLog,
    Employer,
    EmployerUser,
    Job,
    Match,
    Notification,
    OAuthIdentity,
    Resume,
    SavedJob,
    User,
    UserConsent,
    UserRole,
)

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------


class RedactionEntry(BaseModel):
    type: str
    reason: str


class UserExport(BaseModel):
    model_config = ConfigDict(extra="forbid")

    version: str = "1"
    exported_at: datetime
    exported_for_user_id: UUID

    user: dict[str, Any]
    applicant: dict[str, Any] | None = None

    oauth_identities: list[dict[str, Any]] = []
    resumes: list[dict[str, Any]] = []
    applicant_embedding: dict[str, Any] | None = None
    applications: list[dict[str, Any]] = []
    saved_jobs: list[dict[str, Any]] = []
    matches: list[dict[str, Any]] = []
    notifications: list[dict[str, Any]] = []
    user_consents: list[dict[str, Any]] = []
    audit_history: list[dict[str, Any]] = []

    employer_memberships: list[dict[str, Any]] = []
    owned_jobs: list[dict[str, Any]] = []

    redactions: list[RedactionEntry] = []
    notes: list[str] = []


# ---------------------------------------------------------------------------
# Static constants
# ---------------------------------------------------------------------------

_REDACTIONS = [
    RedactionEntry(
        type="refresh_tokens",
        reason=(
            "Session secrets — not personal data; would let an exposed export"
            " be used to impersonate the user."
        ),
    ),
    RedactionEntry(
        type="resume_binaries",
        reason="Metadata included; binaries downloadable on request from privacy@kpa.",
    ),
]

_NOTES = [
    "This export was generated automatically.",
    "For data older than your sign-up date, contact privacy@kpa.",
    "Resume PDFs/DOCXs are not included in this JSON — request copies separately.",
]


# ---------------------------------------------------------------------------
# Row serialization helper
# ---------------------------------------------------------------------------


def _row_to_dict(row: object) -> dict[str, Any]:
    """SQLAlchemy ORM row → dict via column introspection. Includes every
    mapped column; does NOT walk relationships."""
    state = row.__dict__.copy()
    state.pop("_sa_instance_state", None)
    # Convert enums, datetimes, and UUIDs to strings for JSON friendliness.
    # Order matters: StrEnum check must come BEFORE hex check because enum
    # instances also satisfy hasattr(v, "isoformat") or hasattr(v, "hex") in
    # some edge cases; explicit enum handling is always correct and comes first.
    out: dict[str, Any] = {}
    for k, v in state.items():
        if hasattr(v, "value") and hasattr(type(v), "__members__"):  # StrEnum / Enum
            out[k] = v.value
        elif hasattr(v, "isoformat"):  # datetime
            out[k] = v.isoformat()
        elif hasattr(v, "hex"):  # UUID
            out[k] = str(v)
        else:
            out[k] = v
    return out


# ---------------------------------------------------------------------------
# Public builder
# ---------------------------------------------------------------------------


async def build_user_export(
    session: AsyncSession,
    *,
    user: User,
) -> UserExport:
    """Assemble the export envelope. Pure read-only — does not write any
    audit row. The route handler writes the audit rows around this call.

    Raises nothing custom — DB errors propagate to the route, which
    converts to 500 via the standard handler.
    """
    user_dict = _row_to_dict(user)

    applicant_row = (
        await session.execute(select(Applicant).where(Applicant.user_id == user.id))
    ).scalar_one_or_none()
    applicant_dict = _row_to_dict(applicant_row) if applicant_row else None

    oauth_rows = (
        (await session.execute(select(OAuthIdentity).where(OAuthIdentity.user_id == user.id)))
        .scalars()
        .all()
    )

    resumes: list[dict[str, Any]] = []
    embedding_dict: dict[str, Any] | None = None
    applications: list[dict[str, Any]] = []
    saved_jobs: list[dict[str, Any]] = []
    matches: list[dict[str, Any]] = []

    if applicant_row is not None:
        applicant_id = applicant_row.id
        resumes = [
            _row_to_dict(r)
            for r in (
                await session.execute(select(Resume).where(Resume.applicant_id == applicant_id))
            )
            .scalars()
            .all()
        ]
        embedding_row = (
            await session.execute(
                select(ApplicantEmbedding).where(ApplicantEmbedding.applicant_id == applicant_id)
            )
        ).scalar_one_or_none()
        if embedding_row is not None:
            embedding_dict = _row_to_dict(embedding_row)
        applications = [
            _row_to_dict(a)
            for a in (
                await session.execute(
                    select(Application).where(Application.applicant_id == applicant_id)
                )
            )
            .scalars()
            .all()
        ]
        saved_jobs = [
            _row_to_dict(s)
            for s in (
                await session.execute(select(SavedJob).where(SavedJob.applicant_id == applicant_id))
            )
            .scalars()
            .all()
        ]
        matches = [
            _row_to_dict(m)
            for m in (
                await session.execute(select(Match).where(Match.applicant_id == applicant_id))
            )
            .scalars()
            .all()
        ]

    notifications = [
        _row_to_dict(n)
        for n in (
            await session.execute(select(Notification).where(Notification.user_id == user.id))
        )
        .scalars()
        .all()
    ]

    user_consents = [
        _row_to_dict(c)
        for c in (await session.execute(select(UserConsent).where(UserConsent.user_id == user.id)))
        .scalars()
        .all()
    ]

    audit_history = [
        _row_to_dict(a)
        for a in (
            await session.execute(
                select(AuditLog)
                .where(AuditLog.actor_user_id == user.id)
                .order_by(AuditLog.created_at.desc())
            )
        )
        .scalars()
        .all()
    ]

    employer_memberships: list[dict[str, Any]] = []
    owned_jobs: list[dict[str, Any]] = []

    if user.role in (UserRole.RECRUITER, UserRole.ADMIN):
        eu_rows = (
            await session.execute(
                select(EmployerUser, Employer)
                .join(Employer, Employer.id == EmployerUser.employer_id)
                .where(EmployerUser.user_id == user.id)
            )
        ).all()
        for eu, emp in eu_rows:
            entry = _row_to_dict(eu)
            entry["employer"] = _row_to_dict(emp)
            employer_memberships.append(entry)

        if eu_rows:
            employer_ids = [eu.employer_id for eu, _ in eu_rows]
            owned_jobs = [
                _row_to_dict(j)
                for j in (
                    await session.execute(select(Job).where(Job.employer_id.in_(employer_ids)))
                )
                .scalars()
                .all()
            ]

    return UserExport(
        exported_at=datetime.now(UTC),
        exported_for_user_id=user.id,
        user=user_dict,
        applicant=applicant_dict,
        oauth_identities=[_row_to_dict(o) for o in oauth_rows],
        resumes=resumes,
        applicant_embedding=embedding_dict,
        applications=applications,
        saved_jobs=saved_jobs,
        matches=matches,
        notifications=notifications,
        user_consents=user_consents,
        audit_history=audit_history,
        employer_memberships=employer_memberships,
        owned_jobs=owned_jobs,
        redactions=list(_REDACTIONS),
        notes=list(_NOTES),
    )
