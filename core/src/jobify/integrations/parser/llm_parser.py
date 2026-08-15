"""Gemini-backed ResumeParser — one structured-output call over extracted text.

This module imports ``google.genai`` at module load time. Everything else in
the parser package stays genai-free (mirrors ``jobify.scoring.llm_explainer``);
never re-export this class from the package ``__init__``.

Failure contract: any post-extraction failure (provider exception, blocked or
empty response, JSON that fails ``ParsedResume`` validation) raises
:class:`LlmParserError` after logging a PII-safe SHAPE summary at debug (see
``_raw_shape`` — never the response body, which restates the resume).
ONE attempt, no internal retry — :class:`FallbackResumeParser` is the recovery.
Extraction failures (:class:`ParserError` from ``extract_text``) propagate
untouched: they are permanent regardless of parser.

One call shape: ``parse``/``parse_text``, the interactive LIVE path (async,
one ``generate_content`` call) — never move it off interactive, the spec's
≤10-min first-match criterion depends on its latency.

A ``parse_texts_batch`` Gemini Batch API path existed here for the eval lane
(50% pricing, separate quota pool) and was removed 2026-08-15: it had no
caller once the eval lane moved to the paced interactive path, and it was
never verified against the real API (batch returned FAILED_PRECONDITION on
the free tier, then 403 once the project was denied). Recover from git
history if bulk re-parsing becomes real — but verify it live before trusting
it, since its only coverage was mocked.
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any, Final

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


_SCHEMA_KEYS: Final[frozenset[str]] = frozenset(ParsedResume.model_fields)


def _raw_shape(raw: str | None) -> dict[str, Any]:
    """Describe a rejected model response WITHOUT echoing its content.

    The response body is the applicant's resume restated as JSON — name,
    email, phone, employers. Logging even a truncated prefix (this used to
    emit ``raw_model_output=raw[:500]``) put that PII into the log pipeline
    at every validation failure, which is exactly the case most likely to be
    debugged with logs turned up. The same reasoning already governs the
    exception messages here; the debug line was the hole left in it.

    What survives is the diagnostic signal that is not content: how long the
    response was, whether it parsed as JSON, where it stopped parsing, and
    WHICH schema fields came back. Key names are ours (from the response
    schema), not model-authored — unrecognised keys are counted, never named,
    since a malformed response could put content in key position.
    """
    if not raw:
        return {"raw_len": 0, "raw_kind": "empty"}

    shape: dict[str, Any] = {"raw_len": len(raw)}
    try:
        payload: Any = json.loads(raw)
    except json.JSONDecodeError as exc:
        shape["raw_kind"] = "invalid_json"
        shape["json_error_pos"] = exc.pos
        return shape

    if not isinstance(payload, dict):
        shape["raw_kind"] = type(payload).__name__
        return shape

    keys = set(payload)
    shape["raw_kind"] = "object"
    shape["known_keys"] = sorted(keys & _SCHEMA_KEYS)
    shape["unknown_key_count"] = len(keys - _SCHEMA_KEYS)
    return shape


def _generate_content_config() -> types.GenerateContentConfig:
    """Request config for the parse call — system instruction, response
    schema, temperature, thinking budget.

    Still a function rather than a module constant: the on-demand LLM eval
    lane builds its own parser instance, and sharing one mutable config
    object across callers invites action-at-a-distance if anything ever
    tweaks a field.
    """
    return types.GenerateContentConfig(
        system_instruction=_SYSTEM_INSTRUCTION,
        response_mime_type="application/json",
        response_schema=_RESPONSE_SCHEMA,
        temperature=0,
        max_output_tokens=8192,
        # gemini-2.5 thinks by default and thought tokens count against
        # max_output_tokens (see llm_explainer.py's starvation incident).
        # Pure extraction needs no thinking.
        thinking_config=types.ThinkingConfig(thinking_budget=0),
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
        """Post-extraction path — also the CI eval lane's parser-under-test.

        Interactive ``generate_content``, ONE attempt. This is the LIVE path
        — never move it to the Batch API. Its latency is what the spec's
        ≤10-min first-match criterion depends on; batch jobs can take
        anywhere from minutes to hours.
        """
        try:
            resp = await self._client.aio.models.generate_content(
                model=self._model,
                contents=text,
                config=_generate_content_config(),
            )
        except Exception as exc:
            raise LlmParserError(f"llm_call_failed: {type(exc).__name__}") from exc
        raw = getattr(resp, "text", None)
        return self._validated_resume(raw, text)

    def _validated_resume(self, raw: str | None, text: str) -> ParsedResume:
        """Response-text -> ParsedResume validation: JSON parse, schema-drop,
        PII-safe error messages. Kept as its own method (rather than inlined
        into :meth:`parse_text`) because every arm here is a distinct rejection
        mode worth testing in isolation.
        """
        try:
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
            _log.debug("parse.llm-output-rejected", **_raw_shape(raw))
            # str(exc) embeds pydantic's "input_value=..." context, which for
            # this model IS the resume's own PII (name/email/phone/etc). Build
            # the message from a slug + failing top-level field names only —
            # never the offending values.
            fields = sorted({str(e["loc"][0]) for e in exc.errors() if e["loc"]})
            raise LlmParserError(f"llm_output_invalid: validation failed on {fields}") from exc
        except (ValueError, TypeError) as exc:
            # Our own safe messages ("empty response text", "expected object,
            # got ..."); never model-echoed content.
            _log.debug("parse.llm-output-rejected", **_raw_shape(raw))
            raise LlmParserError(f"llm_output_invalid: {exc}") from exc
        except Exception as exc:
            # Blanket arm restoring the module's documented "ANY
            # post-extraction failure raises LlmParserError" contract for
            # whatever falls outside the two specific arms above (e.g. an
            # unexpected error constructing ParsedResume). Type name only —
            # never str(exc), which for this model can carry the resume's
            # own PII the same way ValidationError's message does.
            _log.debug("parse.llm-output-rejected", **_raw_shape(raw))
            raise LlmParserError(f"llm_output_invalid: {type(exc).__name__}") from exc
