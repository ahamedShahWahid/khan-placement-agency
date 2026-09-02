"""job_embeddings — vector(1536) table for job side of matching

Revision ID: 0006
Revises: 0005
Create Date: 2026-05-20

Adds:
- jobify.job_embeddings (vector(1536), unique(job_id), HNSW + vector_cosine_ops)

The pgvector extension was added in 0004; not repeated here.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects import postgresql

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "job_embeddings",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "job_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("jobify.jobs.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("embedding", Vector(1536), nullable=False),
        sa.Column("model_name", sa.String(64), nullable=False),
        sa.Column("canonicalized_text_hash", sa.CHAR(64), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        schema="jobify",
    )
    # HNSW + cosine ops because §6.3 specifies cosine similarity for matching.
    # HNSW at pgvector defaults (m=16, ef_construction=64) — fine for MVP scale.
    #
    # NOTE: nothing QUERIES this index yet. Similarity is computed in pure
    # Python (`jobify.scoring.vector`) because the score workers walk the full
    # open-jobs / all-applicants list rather than a top-K, and /v1/feed orders
    # by the precomputed `matches.total_score` via a btree partial index. So
    # today this is write-side cost only (graph maintenance on every embed
    # UPSERT). It is the deliberate substrate for the top-K ANN swap
    # IMPLEMENTATION_SPEC §15 flags as necessary once applicant x job reaches
    # the millions — the first `ORDER BY embedding <=> :q LIMIT n` query needs
    # it to already exist. Don't assume the feed is ANN-backed; it isn't.
    # Mirrors the applicant-side index from 0004.
    op.execute(
        "CREATE INDEX ix_job_embeddings_hnsw "
        "ON jobify.job_embeddings USING hnsw (embedding vector_cosine_ops)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS jobify.ix_job_embeddings_hnsw")
    op.drop_table("job_embeddings", schema="jobify")
    # Intentionally NOT dropping the vector extension — applicant_embeddings still uses it.
