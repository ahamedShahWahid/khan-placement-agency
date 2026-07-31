"""Cursor encode/decode tests for the feed endpoint — pure functions, no DB."""

from __future__ import annotations

from decimal import Decimal
from uuid import uuid4

import pytest

from jobify_api.routes.feed import decode_cursor, encode_cursor


def test_cursor_roundtrip() -> None:
    score = Decimal("0.8500")
    mid = uuid4()
    cursor = encode_cursor(score, mid)
    assert decode_cursor(cursor) == (score, mid, None)


def test_cursor_score_precision_preserved() -> None:
    score = Decimal("0.8500")
    mid = uuid4()
    decoded_score, _, _ = decode_cursor(encode_cursor(score, mid))
    assert decoded_score == Decimal("0.8500")
    assert str(decoded_score) == "0.8500"


def test_cursor_malformed_base64_rejected() -> None:
    with pytest.raises(ValueError):
        decode_cursor("not_base64!!!")


def test_cursor_missing_keys_rejected() -> None:
    import base64
    import json

    bad = base64.urlsafe_b64encode(json.dumps({"score": "0.5"}).encode()).decode("ascii")
    with pytest.raises(ValueError):
        decode_cursor(bad)


def test_cursor_bad_uuid_rejected() -> None:
    import base64
    import json

    bad = base64.urlsafe_b64encode(
        json.dumps({"score": "0.5", "match_id": "not-a-uuid"}).encode()
    ).decode("ascii")
    with pytest.raises(ValueError):
        decode_cursor(bad)


def test_filters_hash_none_when_no_filters() -> None:
    from jobify_api.routes.feed import filters_hash

    assert filters_hash(None, None, None, None) is None
    assert filters_hash(None, [], None, None) is None


def test_filters_hash_stable_and_canonical() -> None:
    from jobify_api.routes.feed import filters_hash

    a = filters_hash("Flutter", ["Pune", "Remote"], 3, Decimal("500000"))
    b = filters_hash("flutter", ["remote", "PUNE"], 3, Decimal("500000"))
    assert a is not None
    assert a == b  # lowercased + sorted locations canonicalize
    assert len(a) == 12


def test_filters_hash_differs_per_filter_set() -> None:
    from jobify_api.routes.feed import filters_hash

    base = filters_hash("flutter", None, None, None)
    assert base != filters_hash("dart", None, None, None)
    assert base != filters_hash("flutter", ["Pune"], None, None)
    assert base != filters_hash("flutter", None, 3, None)
    assert base != filters_hash("flutter", None, None, Decimal("1"))


def test_cursor_roundtrip_with_filters_hash() -> None:
    from jobify_api.routes.feed import filters_hash

    score, mid = Decimal("0.8500"), uuid4()
    fhash = filters_hash("flutter", ["Pune"], None, None)
    assert decode_cursor(encode_cursor(score, mid, fhash)) == (score, mid, fhash)


def test_cursor_without_hash_decodes_none_f() -> None:
    score, mid = Decimal("0.8500"), uuid4()
    _, _, f = decode_cursor(encode_cursor(score, mid))
    assert f is None


def test_cursor_legacy_payload_without_f_key_decodes() -> None:
    # A pre-deploy cursor has no "f" key at all — must decode as f=None.
    import base64
    import json

    legacy = base64.urlsafe_b64encode(
        json.dumps({"score": "0.5", "match_id": str(uuid4())}).encode()
    ).decode("ascii")
    _, _, f = decode_cursor(legacy)
    assert f is None


def test_cursor_non_string_f_rejected() -> None:
    import base64
    import json

    bad = base64.urlsafe_b64encode(
        json.dumps({"score": "0.5", "match_id": str(uuid4()), "f": 7}).encode()
    ).decode("ascii")
    with pytest.raises(ValueError):
        decode_cursor(bad)
