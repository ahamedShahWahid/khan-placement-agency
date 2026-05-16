"""users + applicants

Revision ID: 0001
Revises:
Create Date: 2026-05-16
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE SCHEMA IF NOT EXISTS kpa")

    user_role = postgresql.ENUM(
        "applicant",
        "recruiter",
        "admin",
        name="user_role",
        schema="kpa",
        create_type=True,
    )
    user_role.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(254), nullable=True),
        sa.Column("phone", sa.String(20), nullable=True),
        sa.Column(
            "role",
            postgresql.ENUM(name="user_role", schema="kpa", create_type=False),
            nullable=False,
        ),
        sa.Column("mfa_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
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
        sa.UniqueConstraint("email", name="uq_users_email"),
        sa.UniqueConstraint("phone", name="uq_users_phone"),
        schema="kpa",
    )
    op.create_index(
        "ix_users_email_live",
        "users",
        ["email"],
        schema="kpa",
        postgresql_where=sa.text("deleted_at IS NULL"),
    )
    op.create_index(
        "ix_users_phone_live",
        "users",
        ["phone"],
        schema="kpa",
        postgresql_where=sa.text("deleted_at IS NULL"),
    )

    op.create_table(
        "applicants",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("kpa.users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("full_name", sa.String(200), nullable=False),
        sa.Column(
            "locations",
            postgresql.ARRAY(sa.String(100)),
            nullable=False,
            server_default=sa.text("'{}'::varchar[]"),
        ),
        sa.Column("notice_period_days", sa.Integer(), nullable=True),
        sa.Column("current_ctc", sa.Numeric(12, 2), nullable=True),
        sa.Column("expected_ctc", sa.Numeric(12, 2), nullable=True),
        sa.Column("years_experience", sa.Numeric(4, 1), nullable=True),
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


def downgrade() -> None:
    op.drop_table("applicants", schema="kpa")
    op.drop_index("ix_users_phone_live", table_name="users", schema="kpa")
    op.drop_index("ix_users_email_live", table_name="users", schema="kpa")
    op.drop_table("users", schema="kpa")
    op.execute("DROP TYPE IF EXISTS kpa.user_role")
    # NOTE: kpa schema is intentionally kept — alembic_version lives there and
    # will be cleared by alembic after this function returns.  Dropping the
    # schema with CASCADE here would destroy alembic_version mid-transaction
    # and leave alembic unable to record the downgrade.
