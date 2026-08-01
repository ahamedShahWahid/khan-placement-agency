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

Two call shapes: ``parse``/``parse_text`` are the interactive LIVE path
(async, one ``generate_content`` call — never touch this for the ≤10-min
first-match criterion). ``parse_texts_batch`` is a sync, eval/bulk-only path
over the Gemini Batch API (50% of interactive pricing, a separate quota
pool) — see its docstring.
"""

from __future__ import annotations

import json
import time
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


def _generate_content_config() -> types.GenerateContentConfig:
    """Shared config for the interactive and batch call shapes — identical
    system instruction/schema/temperature/thinking budget either way, only
    the transport (``generate_content`` vs. an inlined batch request) differs.
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
        (`parse`/`parse_text`) — never move it to batch. Its latency is what
        the spec's ≤10-min first-match criterion depends on; batch jobs can
        take anywhere from minutes to hours. See :meth:`parse_texts_batch`
        for the eval/bulk-only batch lane.
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

    def parse_texts_batch(
        self,
        texts: list[str],
        *,
        poll_interval_s: float = 10.0,
        timeout_s: float = 1800.0,
    ) -> list[ParsedResume]:
        """Batch-mode entry point for the eval lane and future bulk re-parse
        jobs — Gemini Batch API (50% of interactive ``generate_content``
        pricing, a separate quota pool). NEVER call this from the live
        `parse`/`parse_text` path (see their docstrings) — batch jobs are not
        request/response, so this method is deliberately sync and blocks the
        calling thread while polling, unlike every other method here.

        All-or-nothing: a job-level failure/timeout, or ANY per-item failure
        (missing/error response, schema-invalid JSON), raises
        :class:`LlmParserError` naming the failing indices — callers get
        every result (index-aligned with ``texts``) or none, never a partial
        list silently missing entries.
        """
        if not texts:
            return []

        inlined_requests = [
            types.InlinedRequest(contents=text, config=_generate_content_config()) for text in texts
        ]

        try:
            job = self._client.batches.create(model=self._model, src=inlined_requests)
        except Exception as exc:
            raise LlmParserError(f"llm_batch_create_failed: {type(exc).__name__}") from exc

        job_name = job.name
        if job_name is None:
            raise LlmParserError("llm_batch_create_failed: job has no name")

        deadline = time.monotonic() + timeout_s
        while not job.done:
            if time.monotonic() >= deadline:
                raise LlmParserError(
                    f"llm_batch_timeout: job {job_name} still {job.state} after {timeout_s}s"
                )
            time.sleep(poll_interval_s)
            try:
                job = self._client.batches.get(name=job_name)
            except Exception as exc:
                raise LlmParserError(f"llm_batch_poll_failed: {type(exc).__name__}") from exc

        if job.state != types.JobState.JOB_STATE_SUCCEEDED:
            job_error = getattr(job, "error", None)
            _log.debug(
                "parse.llm-batch-job-failed",
                job_name=job_name,
                state=str(job.state),
                error=job_error,
            )
            raise LlmParserError(
                f"llm_batch_job_failed: job {job_name} state={job.state} error={job_error}"
            )

        responses = list(job.dest.inlined_responses or []) if job.dest else []
        if len(responses) != len(texts):
            raise LlmParserError(
                f"llm_batch_response_count_mismatch: expected {len(texts)}, got {len(responses)}"
            )

        # Index order is a documented SDK guarantee for inlined batch
        # requests/responses (google.genai.types.BatchJobDestination.
        # inlined_responses: "will be in the same order as the input
        # requests") — safe to zip positionally against texts.
        results: list[ParsedResume] = []
        failing_indices: list[int] = []
        for idx, (item, text) in enumerate(zip(responses, texts, strict=True)):
            if item.error is not None:
                _log.debug("parse.llm-batch-item-error", index=idx, code=item.error.code)
                failing_indices.append(idx)
                continue
            raw = getattr(item.response, "text", None) if item.response is not None else None
            try:
                results.append(self._validated_resume(raw, text))
            except LlmParserError:
                failing_indices.append(idx)

        if failing_indices:
            raise LlmParserError(f"llm_batch_items_failed: indices {failing_indices}")

        return results

    def _validated_resume(self, raw: str | None, text: str) -> ParsedResume:
        """Shared response-text -> ParsedResume validation for the
        interactive (:meth:`parse_text`) and batch (:meth:`parse_texts_batch`)
        paths — same JSON parse, same schema-drop, same PII-safe error
        messages either way.
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
            # Blanket arm restoring the module's documented "ANY
            # post-extraction failure raises LlmParserError" contract for
            # whatever falls outside the two specific arms above (e.g. an
            # unexpected error constructing ParsedResume). Type name only —
            # never str(exc), which for this model can carry the resume's
            # own PII the same way ValidationError's message does. In the
            # batch loop this keeps an unforeseen failure scoped to its own
            # index instead of raising an uncaught exception that aborts the
            # whole batch.
            _log.debug("parse.llm-raw-output", raw_model_output=(raw or "")[:500])
            raise LlmParserError(f"llm_output_invalid: {type(exc).__name__}") from exc
