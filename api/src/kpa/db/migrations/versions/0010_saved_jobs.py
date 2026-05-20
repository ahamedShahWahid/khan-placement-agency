"""saved_jobs — applicant x job save rows

Revision ID: 0010
Revises: 0009
Create Date: 2026-05-20

Adds:
- kpa.saved_jobs (partial-UNIQUE on (applicant_id, job_id) WHERE deleted_at IS NULL)
- Two partial indexes (UPSERT target + applicant timeline query)
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "saved_jobs",
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
        "ix_saved_jobs_applicant_job_live",
        "saved_jobs",
        ["applicant_id", "job_id"],
        unique=True,
        schema="kpa",
        postgresql_where=sa.text("deleted_at IS NULL"),
    )

    # Timeline query: WHERE applicant_id = $1 AND deleted_at IS NULL ORDER BY created_at DESC.
    # Raw SQL because op.create_index can't portably express DESC ordering.
    op.execute(
        "CREATE INDEX ix_saved_jobs_applicant_created_at "
        "ON kpa.saved_jobs (applicant_id, created_at DESC) "
        "WHERE deleted_at IS NULL"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS kpa.ix_saved_jobs_applicant_created_at")
    op.drop_index("ix_saved_jobs_applicant_job_live", table_name="saved_jobs", schema="kpa")
    op.drop_table("saved_jobs", schema="kpa")
