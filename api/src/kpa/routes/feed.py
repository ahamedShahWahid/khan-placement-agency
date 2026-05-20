"""GET /v1/feed — paginated ranked matches for the current applicant.

Cursor pagination via opaque base64 of {score, match_id}. ETag is weak,
keyed off (applicant_id, max(updated_at), count). 401/403 ladder reuses the
existing current_user + _require_applicant deps from auth + resumes routes.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import json
import uuid
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

# --- Pydantic *Read models ---


class MatchRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    total_score: float
    vector_score: float
    structured_score: float
    components: dict[str, float]
    surfaced_at: datetime | None


class EmployerRead(BaseModel):
    """Wire shape: a verified bool, not the underlying verified_at timestamp."""

    model_config = ConfigDict(from_attributes=False)

    id: uuid.UUID
    name: str
    verified: bool


class JobRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    description: str
    locations: list[str]
    min_exp_years: int
    max_exp_years: int
    ctc_min: float | None
    ctc_max: float | None
    posted_at: datetime


class FeedItemRead(BaseModel):
    match: MatchRead
    job: JobRead
    employer: EmployerRead


class FeedResponse(BaseModel):
    items: list[FeedItemRead]
    next_cursor: str | None


class JobDetailResponse(BaseModel):
    job: JobRead
    employer: EmployerRead
    match: MatchRead | None


# --- Cursor helpers ---


def encode_cursor(score: Decimal, match_id: uuid.UUID) -> str:
    """Pack (score, match_id) into an opaque base64 string."""
    payload = {"score": str(score), "match_id": str(match_id)}
    raw = json.dumps(payload).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii")


def decode_cursor(cursor: str) -> tuple[Decimal, uuid.UUID]:
    """Decode an opaque cursor. Raises ValueError on any malformed input."""
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii"))
        payload = json.loads(raw)
        return Decimal(payload["score"]), uuid.UUID(payload["match_id"])
    except (ValueError, KeyError, TypeError, json.JSONDecodeError, binascii.Error) as exc:
        raise ValueError(f"invalid_cursor: {exc}") from exc


# --- ETag helper ---


def make_weak_etag(*parts: object) -> str:
    """W/\"<sha256-hex>\" of str-rendered parts joined by '|'.

    Weak ETag because the body is computed from joined data — we promise
    semantic equivalence, not byte-exact reproducibility.
    """
    raw = "|".join(str(p) for p in parts)
    return f'W/"{hashlib.sha256(raw.encode("utf-8")).hexdigest()}"'
