"""applications — applicant x job application rows

Revision ID: 0009
Revises: 0008
Create Date: 2026-05-20

Adds:
- kpa.application_status ENUM ('applied', 'withdrawn')
- kpa.applications (partial-UNIQUE on (applicant_id, job_id) WHERE deleted_at IS NULL)
- Two partial indexes (UPSERT target + applicant timeline query)
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    application_status = postgresql.ENUM(
        "applied",
        "withdrawn",
        name="application_status",
        schema="kpa",
        create_type=True,
    )
    application_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "applications",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "applicant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("kpa.applicants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "job_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("kpa.jobs.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "status",
            postgresql.ENUM(name="application_status", schema="kpa", create_type=False),
            nullable=False,
            server_default=sa.text("'applied'::kpa.application_status"),
        ),
        sa.Column("source", sa.String(32), nullable=False, server_default="feed"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        schema="kpa",
    )

    # UPSERT target + live-row enforcer — partial UNIQUE.
    op.create_index(
        "ix_applications_applicant_job_live",
        "applications",
        ["applicant_id", "job_id"],
        unique=True,
        schema="kpa",
        postgresql_where=sa.text("deleted_at IS NULL"),
    )

    # Timeline query: WHERE applicant_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC.
    # Raw SQL because op.create_index can't portably express DESC ordering.
    op.execute(
        "CREATE INDEX ix_applications_applicant_created_at "
        "ON kpa.applications (applicant_id, created_at DESC) "
        "WHERE deleted_at IS NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS kpa.ix_applications_applicant_created_at")
    op.drop_index("ix_applications_applicant_job_live", table_name="applications", schema="kpa")
    op.drop_table("applications", schema="kpa")
    postgresql.ENUM(
        "applied",
        "withdrawn",
        name="application_status",
        schema="kpa",
    ).drop(op.get_bind(), checkfirst=True)
