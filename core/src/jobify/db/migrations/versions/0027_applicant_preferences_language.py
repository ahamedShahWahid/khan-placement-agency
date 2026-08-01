"""applicant preferences: language column (en|hi)

Revision ID: 0027
Revises: 0026
Create Date: 2026-08-01

Adds applicant_preferences.language (varchar+CHECK, default 'en' — existing
rows are backfilled by the server default). Joins _PREFERENCES_MATCHING_FIELDS
as a rescore trigger (scores unchanged, but the LLM explainer regenerates in
the applicant's chosen language). Vocabulary 'en','hi'. See
docs/superpowers/specs/2026-08-01-hindi-i18n-design.md.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0027"
down_revision = "0026"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "applicant_preferences",
        sa.Column("language", sa.String(8), nullable=False, server_default="en"),
        schema="jobify",
    )
    op.create_check_constraint(
        "ck_applicant_preferences_language",
        "applicant_preferences",
        "language IN ('en','hi')",
        schema="jobify",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_applicant_preferences_language",
        "applicant_preferences",
        schema="jobify",
        type_="check",
    )
    op.drop_column("applicant_preferences", "language", schema="jobify")
