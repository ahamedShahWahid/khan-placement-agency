"""GeminiResumeParser — faked genai client; no network."""

from __future__ import annotations

import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from google.genai import types

from jobify.integrations.parser import LlmParserError, ParserError
from jobify.integrations.parser import llm_parser as llm_parser_module
from jobify.integrations.parser.llm_parser import LLM_PARSER_NAME, GeminiResumeParser

_GOOD_JSON = json.dumps(
    {
        "name": "Priya Sharma",
        "email": "priya@example.com",
        "phone": "+91 98765 43210",
        "skills": ["Python", "FastAPI"],
        "experience": [
            {
                "company": "Acme",
                "title": "Engineer",
                "start": "Jan 2020",
                "end": "Present",
                "summary": "Built things.",
            }
        ],
        "education": [
            {
                "institution": "IIT Delhi",
                "degree": "B.Tech",
                "field": "Computer Science",
                "end_year": 2019,
            }
        ],
        "certifications": [],
    }
)


def _client_returning(text: str | None) -> MagicMock:
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(return_value=SimpleNamespace(text=text))
    return client


def test_parse_text_happy_path() -> None:
    parser = GeminiResumeParser(client=_client_returning(_GOOD_JSON), model="gemini-2.5-flash")
    parsed = asyncio.run(parser.parse_text("PRIYA SHARMA\npriya@example.com ..."))
    assert parsed.parser_name == LLM_PARSER_NAME
    assert parsed.raw_text.startswith("PRIYA SHARMA")
    assert parsed.name == "Priya Sharma"
    assert parsed.skills == ["Python", "FastAPI"]
    assert parsed.experience[0].company == "Acme"
    assert parsed.education[0].end_year == 2019
    assert parsed.schema_version == 1


def test_empty_response_raises_llm_error() -> None:
    parser = GeminiResumeParser(client=_client_returning(None), model="m")
    with pytest.raises(LlmParserError):
        asyncio.run(parser.parse_text("text"))


def test_invalid_json_raises_llm_error() -> None:
    parser = GeminiResumeParser(client=_client_returning("not json {"), model="m")
    with pytest.raises(LlmParserError):
        asyncio.run(parser.parse_text("text"))


def test_schema_invalid_payload_raises_llm_error() -> None:
    # end_year must be an int — a string that pydantic can't coerce fails validation.
    bad = json.dumps({"education": [{"end_year": "two thousand"}]})
    parser = GeminiResumeParser(client=_client_returning(bad), model="m")
    with pytest.raises(LlmParserError):
        asyncio.run(parser.parse_text("text"))


def test_schema_invalid_payload_error_message_scrubs_pii() -> None:
    """A ValidationError's str() embeds pydantic's input_value=... context —
    for ParsedResume that context is the model-echoed resume fields
    themselves. The raised LlmParserError (which fallback.py logs at WARNING)
    must name the failing field but never leak the offending value."""
    leaked_email = "leaked-pii@example.com"
    bad = json.dumps({"education": [{"end_year": leaked_email}]})
    parser = GeminiResumeParser(client=_client_returning(bad), model="m")
    with pytest.raises(LlmParserError) as exc_info:
        asyncio.run(parser.parse_text("text"))
    message = str(exc_info.value)
    assert leaked_email not in message
    assert "education" in message


def test_provider_exception_wrapped_as_llm_error() -> None:
    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(side_effect=RuntimeError("503"))
    parser = GeminiResumeParser(client=client, model="m")
    with pytest.raises(LlmParserError):
        asyncio.run(parser.parse_text("text"))


def test_parse_propagates_extraction_error_without_model_call() -> None:
    client = _client_returning(_GOOD_JSON)
    parser = GeminiResumeParser(client=client, model="m")
    # Empty PDF bytes -> extract_text raises a plain ParserError before any model call.
    with pytest.raises(ParserError) as exc_info:
        asyncio.run(parser.parse(content=b"", content_type="application/pdf"))
    assert not isinstance(exc_info.value, LlmParserError)
    client.aio.models.generate_content.assert_not_called()


# --- parse_texts_batch (Gemini Batch API) -----------------------------------


def _fake_job(
    *, name: str = "batches/fake-job", done: bool, state: types.JobState, dest: object = None
) -> SimpleNamespace:
    return SimpleNamespace(name=name, done=done, state=state, dest=dest)


def _inlined_response(*, text: str | None = None, error: object = None) -> SimpleNamespace:
    response = SimpleNamespace(text=text) if text is not None else None
    return SimpleNamespace(response=response, error=error)


def _batch_client(*, create_job: object, get_side_effect: object = None) -> MagicMock:
    client = MagicMock()
    client.batches.create = MagicMock(return_value=create_job)
    if get_side_effect is not None:
        client.batches.get = MagicMock(side_effect=get_side_effect)
    return client


def test_parse_texts_batch_empty_list_is_noop() -> None:
    client = MagicMock()
    parser = GeminiResumeParser(client=client, model="m")
    assert parser.parse_texts_batch([]) == []
    client.batches.create.assert_not_called()


def test_parse_texts_batch_happy_path() -> None:
    second_json = json.dumps({**json.loads(_GOOD_JSON), "name": "Second Person"})
    done_job = _fake_job(
        done=True,
        state=types.JobState.JOB_STATE_SUCCEEDED,
        dest=SimpleNamespace(
            inlined_responses=[
                _inlined_response(text=_GOOD_JSON),
                _inlined_response(text=second_json),
            ]
        ),
    )
    # create() returns a still-running job; the first poll returns the
    # terminal one — exercises the poll loop, not just an immediately-done job.
    running_job = _fake_job(done=False, state=types.JobState.JOB_STATE_RUNNING)
    client = _batch_client(create_job=running_job, get_side_effect=[done_job])
    parser = GeminiResumeParser(client=client, model="gemini-2.5-flash")

    results = parser.parse_texts_batch(["text one", "text two"], poll_interval_s=0)

    assert len(results) == 2
    assert results[0].parser_name == LLM_PARSER_NAME
    assert results[0].name == "Priya Sharma"
    assert results[0].raw_text == "text one"
    assert results[1].name == "Second Person"
    assert results[1].raw_text == "text two"
    client.batches.create.assert_called_once()
    client.batches.get.assert_called_once_with(name="batches/fake-job")


def test_parse_texts_batch_item_invalid_json_names_failing_index() -> None:
    job = _fake_job(
        done=True,
        state=types.JobState.JOB_STATE_SUCCEEDED,
        dest=SimpleNamespace(
            inlined_responses=[
                _inlined_response(text=_GOOD_JSON),
                _inlined_response(text="not json {"),
            ]
        ),
    )
    client = _batch_client(create_job=job)
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError) as exc_info:
        parser.parse_texts_batch(["text one", "text two"], poll_interval_s=0)
    assert "[1]" in str(exc_info.value)


def test_parse_texts_batch_item_error_names_failing_index() -> None:
    job = _fake_job(
        done=True,
        state=types.JobState.JOB_STATE_SUCCEEDED,
        dest=SimpleNamespace(
            inlined_responses=[
                _inlined_response(error=SimpleNamespace(code=8, message="RESOURCE_EXHAUSTED")),
                _inlined_response(text=_GOOD_JSON),
            ]
        ),
    )
    client = _batch_client(create_job=job)
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError) as exc_info:
        parser.parse_texts_batch(["text one", "text two"], poll_interval_s=0)
    assert "[0]" in str(exc_info.value)


def _flaky_parsed_resume_factory(*, raise_on_call: int) -> object:
    """Stand-in for ParsedResume that raises RuntimeError (an exception type
    outside _validated_resume's two specific arms) on the Nth invocation and
    otherwise delegates to the real constructor."""
    real_parsed_resume = llm_parser_module.ParsedResume
    call_count = 0

    def _fn(*args: object, **kwargs: object) -> object:
        nonlocal call_count
        call_count += 1
        if call_count == raise_on_call:
            raise RuntimeError("unexpected boom — not Validation/Value/TypeError")
        return real_parsed_resume(*args, **kwargs)

    return _fn


def test_validated_resume_unexpected_exception_is_wrapped_per_item(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """An exception outside the two specific arms (ValidationError,
    ValueError/TypeError) — e.g. an unforeseen bug constructing ParsedResume
    — must still be caught by _validated_resume's blanket arm and wrapped as
    LlmParserError (type name only, never str(exc)), per the module's
    documented "ANY post-extraction failure raises LlmParserError" contract.
    In the batch loop this must be collected per-item (naming the failing
    index), not left to abort the whole batch."""
    direct_parser = GeminiResumeParser(client=MagicMock(), model="m")
    monkeypatch.setattr(
        llm_parser_module, "ParsedResume", _flaky_parsed_resume_factory(raise_on_call=1)
    )
    with pytest.raises(LlmParserError) as direct_exc:
        direct_parser._validated_resume(_GOOD_JSON, "text")
    assert str(direct_exc.value) == "llm_output_invalid: RuntimeError"

    job = _fake_job(
        done=True,
        state=types.JobState.JOB_STATE_SUCCEEDED,
        dest=SimpleNamespace(
            inlined_responses=[
                _inlined_response(text=_GOOD_JSON),
                _inlined_response(text=_GOOD_JSON),
            ]
        ),
    )
    client = _batch_client(create_job=job)
    batch_parser = GeminiResumeParser(client=client, model="m")
    monkeypatch.setattr(
        llm_parser_module, "ParsedResume", _flaky_parsed_resume_factory(raise_on_call=2)
    )

    with pytest.raises(LlmParserError) as batch_exc:
        batch_parser.parse_texts_batch(["text one", "text two"], poll_interval_s=0)
    assert "[1]" in str(batch_exc.value)


def test_parse_texts_batch_response_count_mismatch_raises() -> None:
    job = _fake_job(
        done=True,
        state=types.JobState.JOB_STATE_SUCCEEDED,
        dest=SimpleNamespace(inlined_responses=[_inlined_response(text=_GOOD_JSON)]),
    )
    client = _batch_client(create_job=job)
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError):
        parser.parse_texts_batch(["text one", "text two"], poll_interval_s=0)


def test_parse_texts_batch_job_failure_state_raises() -> None:
    job = _fake_job(done=True, state=types.JobState.JOB_STATE_FAILED)
    client = _batch_client(create_job=job)
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError):
        parser.parse_texts_batch(["text one"], poll_interval_s=0)


def test_parse_texts_batch_create_failure_wrapped_as_llm_error() -> None:
    client = MagicMock()
    client.batches.create = MagicMock(side_effect=RuntimeError("503"))
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError):
        parser.parse_texts_batch(["text one"])


def test_parse_texts_batch_timeout_raises() -> None:
    never_done_job = _fake_job(done=False, state=types.JobState.JOB_STATE_RUNNING)
    client = _batch_client(create_job=never_done_job, get_side_effect=lambda **_kw: never_done_job)
    parser = GeminiResumeParser(client=client, model="m")

    with pytest.raises(LlmParserError) as exc_info:
        parser.parse_texts_batch(["text one"], poll_interval_s=0.01, timeout_s=0.03)
    assert "timeout" in str(exc_info.value).lower()
