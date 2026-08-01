"""Gemini-backed ResumeParser — one structured-output call over extracted text.

This module imports ``google.genai`` at module load time. Everything else in
the parser package stays genai-free (mirrors ``jobify.scoring.llm_explainer``);
never re-export this class from the package ``__init__``.

Failure contract: any post-extraction failure (provider exception, blocked or
empty response, JSON that fails ``ParsedResume`` validation) raises
:class:`LlmParserError` after logging the truncated raw model text at debug.
ONE attempt, no internal retry — :class:`FallbackResumeParser` is the recovery.
Extraction failures (:class:`ParserError` from ``extract_text``) propagate
untouched: they are permanent regardless of parser.
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

import structlog
from google.genai import types
from pydantic import ValidationError

from jobify.integrations.parser.base import LlmParserError, ParsedResume
from jobify.integrations.parser.text import extract_text

if TYPE_CHECKING:
    from google.genai import Client as GenaiClient

_log = structlog.get_logger(__name__)

LLM_PARSER_NAME = "llm.gemini.v1"

_SYSTEM_INSTRUCTION = (
    "You are Jobify's resume parser. Extract ONLY information that is "
    "explicitly present in the resume text. Never infer or invent values: a "
    "field that is not stated stays null, a list with no stated items stays "
    "empty. Copy date strings verbatim as written (e.g. 'Jan 2020', "
    "'2020-2022', 'Present') — do not normalize them. skills is a flat list "
    "of individual skill names. Return JSON matching the response schema."
)

_ENTRY_STR = types.Schema(type=types.Type.STRING, nullable=True)

_RESPONSE_SCHEMA = types.Schema(
    type=types.Type.OBJECT,
    properties={
        "name": _ENTRY_STR,
        "email": _ENTRY_STR,
        "phone": _ENTRY_STR,
        "skills": types.Schema(type=types.Type.ARRAY, items=types.Schema(type=types.Type.STRING)),
        "experience": types.Schema(
            type=types.Type.ARRAY,
            items=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "company": _ENTRY_STR,
                    "title": _ENTRY_STR,
                    "start": _ENTRY_STR,
                    "end": _ENTRY_STR,
                    "summary": _ENTRY_STR,
                },
            ),
        ),
        "education": types.Schema(
            type=types.Type.ARRAY,
            items=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "institution": _ENTRY_STR,
                    "degree": _ENTRY_STR,
                    "field": _ENTRY_STR,
                    "end_year": types.Schema(type=types.Type.INTEGER, nullable=True),
                },
            ),
        ),
        "certifications": types.Schema(
            type=types.Type.ARRAY,
            items=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "name": _ENTRY_STR,
                    "issuer": _ENTRY_STR,
                    "year": types.Schema(type=types.Type.INTEGER, nullable=True),
                },
            ),
        ),
    },
)


class GeminiResumeParser:
    """Constructor-injected genai client + model (explainer precedent).

    Tests pass a MagicMock; production wires this via
    ``jobify_worker.runtime.get_resume_parser``.
    """

    def __init__(self, *, client: GenaiClient, model: str) -> None:
        self._client = client
        self._model = model

    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume:
        # ParserError from extraction propagates untouched (permanent for
        # any parser; the fallback composite re-raises it too).
        text = await extract_text(content=content, content_type=content_type)
        return await self.parse_text(text)

    async def parse_text(self, text: str) -> ParsedResume:
        """Post-extraction path — also the eval harness's LLM-lane entry."""
        raw: str | None = None
        try:
            resp = await self._client.aio.models.generate_content(
                model=self._model,
                contents=text,
                config=types.GenerateContentConfig(
                    system_instruction=_SYSTEM_INSTRUCTION,
                    response_mime_type="application/json",
                    response_schema=_RESPONSE_SCHEMA,
                    temperature=0,
                    max_output_tokens=8192,
                    # gemini-2.5 thinks by default and thought tokens count
                    # against max_output_tokens (see llm_explainer.py's
                    # starvation incident). Pure extraction needs no thinking.
                    thinking_config=types.ThinkingConfig(thinking_budget=0),
                ),
            )
            raw = getattr(resp, "text", None)
            if not raw:
                raise ValueError("empty response text")
            payload: Any = json.loads(raw)
            if not isinstance(payload, dict):
                raise ValueError(f"expected object, got {type(payload).__name__}")
            payload.pop("schema_version", None)
            payload.pop("parser_name", None)
            payload.pop("raw_text", None)
            return ParsedResume(
                parser_name=LLM_PARSER_NAME,
                raw_text=text,
                **payload,
            )
        except ValidationError as exc:
            _log.debug("parse.llm-raw-output", raw_model_output=(raw or "")[:500])
            # str(exc) embeds pydantic's "input_value=..." context, which for
            # this model IS the resume's own PII (name/email/phone/etc). Build
            # the message from a slug + failing top-level field names only —
            # never the offending values.
            fields = sorted({str(e["loc"][0]) for e in exc.errors() if e["loc"]})
            raise LlmParserError(f"llm_output_invalid: validation failed on {fields}") from exc
        except (ValueError, TypeError) as exc:
            # Our own safe messages ("empty response text", "expected object,
            # got ..."); never model-echoed content.
            _log.debug("parse.llm-raw-output", raw_model_output=(raw or "")[:500])
            raise LlmParserError(f"llm_output_invalid: {exc}") from exc
        except Exception as exc:
            raise LlmParserError(f"llm_call_failed: {type(exc).__name__}") from exc
