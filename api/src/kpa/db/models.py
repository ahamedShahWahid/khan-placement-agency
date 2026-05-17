"""SQLAlchemy declarative models for the KPA service.

Per IMPLEMENTATION_SPEC.md §4.2: SQLAlchemy 2.x style with typed Mapped
columns. Never use these as response schemas — separate Pydantic *Read /
*Create / *Update models belong in the domain modules.

Per §5: every domain table carries `id` (UUID), `created_at`, `updated_at`,
and `deleted_at TIMESTAMPTZ NULL` for soft delete.
"""

from __future__ import annotations

import uuid
from datetime import datetime
from enum import StrEnum
from typing import Annotated, Any

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Integer, Numeric, String, Text, func
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Declarative base. Lives in the `kpa` schema."""

    __table_args__: Any = {"schema": "kpa"}  # noqa: RUF012 — SQLAlchemy base declares this as Any


UuidPK = Annotated[
    uuid.UUID,
    mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    ),
]
CreatedAt = Annotated[
    datetime,
    mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    ),
]
UpdatedAt = Annotated[
    datetime,
    mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    ),
]
DeletedAt = Annotated[
    datetime | None,
    mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=False,  # partial index added per-table in the migration.
    ),
]


class UserRole(StrEnum):
    APPLICANT = "applicant"
    RECRUITER = "recruiter"
    ADMIN = "admin"


class User(Base):
    """Auth principal — see spec §5."""

    __tablename__ = "users"

    id: Mapped[UuidPK]
    email: Mapped[str | None] = mapped_column(String(254), nullable=True, unique=True)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True)
    role: Mapped[UserRole] = mapped_column(
        SAEnum(
            UserRole,
            name="user_role",
            native_enum=True,
            schema="kpa",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
    )
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[CreatedAt]
    updated_at: Mapped[UpdatedAt]
    deleted_at: Mapped[DeletedAt]

    __table_args__ = (
        Index("ix_users_email_live", "email", postgresql_where="deleted_at IS NULL"),
        Index("ix_users_phone_live", "phone", postgresql_where="deleted_at IS NULL"),
        {"schema": "kpa"},
    )


class Applicant(Base):
    """Applicant profile — see spec §5."""

    __tablename__ = "applicants"

    id: Mapped[UuidPK]
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("kpa.users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    full_name: Mapped[str] = mapped_column(String(200), nullable=False)
    locations: Mapped[list[str]] = mapped_column(
        ARRAY(String(100)), nullable=False, server_default="{}"
    )
    notice_period_days: Mapped[int | None] = mapped_column(Integer, nullable=True)
    current_ctc: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)
    expected_ctc: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)
    years_experience: Mapped[float | None] = mapped_column(Numeric(4, 1), nullable=True)
    created_at: Mapped[CreatedAt]
    updated_at: Mapped[UpdatedAt]
    deleted_at: Mapped[DeletedAt]


class ResumeParseStatus(StrEnum):
    PENDING = "pending"
    PARSING = "parsing"
    PARSED = "parsed"
    FAILED = "failed"


class Resume(Base):
    """Uploaded resume — see spec §6.1 and the P1.0 design doc.

    In this slice, every row is created with parse_status='pending' and never
    transitions. The parse worker plan moves rows through parsing → parsed/failed.
    """

    __tablename__ = "resumes"

    id: Mapped[UuidPK]
    applicant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("kpa.applicants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    storage_key: Mapped[str] = mapped_column(String(512), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(127), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    parse_status: Mapped[ResumeParseStatus] = mapped_column(
        SAEnum(
            ResumeParseStatus,
            name="resume_parse_status",
            native_enum=True,
            schema="kpa",
            values_callable=lambda x: [e.value for e in x],
        ),
        nullable=False,
        default=ResumeParseStatus.PENDING,
        server_default=ResumeParseStatus.PENDING.value,
    )
    parsed_json: Mapped[dict[str, Any] | None] = mapped_column(JSONB, nullable=True)
    parse_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[CreatedAt]
    updated_at: Mapped[UpdatedAt]
    deleted_at: Mapped[DeletedAt]
