"""GeminiResumeParser — faked genai client; no network."""

from __future__ import annotations

import asyncio
import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from jobify.integrations.parser import LlmParserError, ParserError
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
