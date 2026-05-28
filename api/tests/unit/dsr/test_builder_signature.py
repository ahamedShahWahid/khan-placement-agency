"""Pure-signature contract test for build_user_export. No DB."""

from __future__ import annotations

import inspect

from kpa.dsr import UserExport, build_user_export


def test_builder_signature() -> None:
    sig = inspect.signature(build_user_export)
    params = list(sig.parameters)
    assert params[0] == "session"
    assert sig.parameters["user"].kind == inspect.Parameter.KEYWORD_ONLY


def test_user_export_top_level_fields() -> None:
    fields = set(UserExport.model_fields.keys())
    expected = {
        "version",
        "exported_at",
        "exported_for_user_id",
        "user",
        "applicant",
        "oauth_identities",
        "resumes",
        "applicant_embedding",
        "applications",
        "saved_jobs",
        "matches",
        "notifications",
        "user_consents",
        "audit_history",
        "employer_memberships",
        "owned_jobs",
        "redactions",
        "notes",
    }
    assert fields == expected, f"missing={expected - fields}, extra={fields - expected}"
