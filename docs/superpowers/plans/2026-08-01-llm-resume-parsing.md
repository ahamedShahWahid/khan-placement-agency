# LLM Resume Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gemini-backed resume parser behind the existing `ResumeParser` Protocol with library fallback, a two-lane F1 eval (deterministic CI lane + on-demand LLM lane at ≥ 0.90), and a 8→20 gold-dataset growth — per `docs/superpowers/specs/2026-08-01-llm-resume-parsing-design.md`.

**Architecture:** Three small units in core (`LlmParserError`, `FallbackResumeParser`, `GeminiResumeParser` — constructor-injected, no genai import outside the llm module), a worker-runtime factory `get_resume_parser()` mirroring `get_match_explainer()`, and a `parse_fn` seam in the eval harness so both lanes share scoring.

**Tech Stack:** Python 3.12, pydantic v2, google-genai SDK (already a dependency), pytest (`-m eval` lane), Celery worker (unchanged semantics).

## Global Constraints

- Work happens on the existing branch `llm-resume-parsing` (already created; spec committed on it).
- All commands from repo root, `uv` only.
- CI-verbatim gates (run before claiming green): `uv run ruff check core/src api/src worker/src tests` · `uv run ruff format --check core/src api/src worker/src tests` · `uv run mypy` · `uv run pytest -v -m "not integration and not eval"` · `uv run pytest -v -s -m eval` · `uv run pytest -v -m integration`.
- **CI never calls Gemini**: the always-run eval test stays deterministic (library parser); the LLM-lane test must skip cleanly when `JOBIFY_GEMINI_API_KEY` or `JOBIFY_PARSE_EVAL_PARSER=llm` is absent.
- `core` modules must import cleanly without the genai SDK loaded — only `parser/llm_parser.py` may import `google.genai`, and nothing else may import that module at package level.
- `thinking_budget=0`, `temperature=0`, `max_output_tokens=8192`, `response_mime_type="application/json"` on the Gemini call — exact values, per spec.
- Provenance strings: `llm.gemini.v1` (LLM), `library.v1` (library, existing).
- Library CI gate stays: overall ≥ 0.85, floors email .95 / phone .85 / name .70 / skills .75 — never silently lowered. New gold examples must leave the library lane green.
- structlog only; never log resume text in error paths (error class + truncated raw model output at debug only).
- No DB migration; `ParsedResume.schema_version` stays 1.

---

### Task 1: `LlmParserError` + `FallbackResumeParser` (core, pure)

**Files:**
- Modify: `core/src/jobify/integrations/parser/base.py` (add `LlmParserError`)
- Create: `core/src/jobify/integrations/parser/fallback.py`
- Modify: `core/src/jobify/integrations/parser/__init__.py` (exports)
- Test: `tests/unit/parser/test_fallback_parser.py` (create; `tests/unit/parser/` may need an empty `__init__.py` only if siblings have one — check `ls tests/unit` for the existing layout and mirror it)

**Interfaces:**
- Produces: `class LlmParserError(ParserError)` in `base.py` — raised by the LLM parser for any post-extraction failure; subclassing `ParserError` keeps it permanent-class if it ever escapes.
- Produces: `class FallbackResumeParser` with `__init__(self, *, primary: ResumeParser, fallback: ResumeParser)` and `async parse(self, *, content: bytes, content_type: str) -> ParsedResume`. Task 3's factory constructs it; Task 3's integration tests exercise it.

- [ ] **Step 1: Write the failing tests**

`tests/unit/parser/test_fallback_parser.py`:

```python
"""FallbackResumeParser — primary/fallback routing and error layering."""

from __future__ import annotations

import pytest

from jobify.integrations.parser import (
    FallbackResumeParser,
    LlmParserError,
    ParsedResume,
    ParserError,
)


class _StubParser:
    def __init__(self, *, result: ParsedResume | None = None, raises: Exception | None = None):
        self.calls = 0
        self._result = result
        self._raises = raises

    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume:
        self.calls += 1
        if self._raises is not None:
            raise self._raises
        assert self._result is not None
        return self._result


def _resume(name: str) -> ParsedResume:
    return ParsedResume(parser_name=name, raw_text="x")


async def _run(parser: FallbackResumeParser) -> ParsedResume:
    return await parser.parse(content=b"pdf-bytes", content_type="application/pdf")


def test_primary_success_never_calls_fallback() -> None:
    import asyncio

    primary = _StubParser(result=_resume("llm.gemini.v1"))
    fallback = _StubParser(result=_resume("library.v1"))
    parsed = asyncio.run(_run(FallbackResumeParser(primary=primary, fallback=fallback)))
    assert parsed.parser_name == "llm.gemini.v1"
    assert fallback.calls == 0


def test_llm_error_falls_back() -> None:
    import asyncio

    primary = _StubParser(raises=LlmParserError("llm_invalid_json"))
    fallback = _StubParser(result=_resume("library.v1"))
    parsed = asyncio.run(_run(FallbackResumeParser(primary=primary, fallback=fallback)))
    assert parsed.parser_name == "library.v1"
    assert primary.calls == 1
    assert fallback.calls == 1


def test_unexpected_exception_falls_back() -> None:
    import asyncio

    primary = _StubParser(raises=RuntimeError("socket burp"))
    fallback = _StubParser(result=_resume("library.v1"))
    parsed = asyncio.run(_run(FallbackResumeParser(primary=primary, fallback=fallback)))
    assert parsed.parser_name == "library.v1"


def test_extraction_parser_error_propagates_uncaught() -> None:
    import asyncio

    primary = _StubParser(raises=ParserError("password_protected"))
    fallback = _StubParser(result=_resume("library.v1"))
    with pytest.raises(ParserError) as exc_info:
        asyncio.run(_run(FallbackResumeParser(primary=primary, fallback=fallback)))
    assert str(exc_info.value) == "password_protected"
    assert fallback.calls == 0
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/unit/parser/test_fallback_parser.py -v`
Expected: FAIL — `ImportError: cannot import name 'FallbackResumeParser'`.

- [ ] **Step 3: Implement**

Append to `core/src/jobify/integrations/parser/base.py`:

```python
class LlmParserError(ParserError):
    """Post-extraction failure inside the LLM parser (API error, blocked/empty
    response, schema-invalid JSON). Subclasses :class:`ParserError` so it stays
    permanent-class if it ever escapes the fallback composite; the composite
    catches it (and any non-ParserError) and runs the fallback parser instead.
    """
```

Create `core/src/jobify/integrations/parser/fallback.py`:

```python
"""Primary-with-fallback composite over two ResumeParser impls.

Policy in one testable place: try the primary; if it fails for any reason
OTHER than a plain extraction :class:`ParserError` (corrupt file, password
protected — permanent regardless of parser), log and run the fallback on the
same input. :class:`LlmParserError` is deliberately caught BEFORE its parent
``ParserError`` — order matters.
"""

from __future__ import annotations

import structlog

from jobify.integrations.parser.base import (
    LlmParserError,
    ParsedResume,
    ParserError,
    ResumeParser,
)

_log = structlog.get_logger(__name__)


class FallbackResumeParser:
    """Try ``primary``; degrade to ``fallback`` unless extraction itself failed."""

    def __init__(self, *, primary: ResumeParser, fallback: ResumeParser) -> None:
        self._primary = primary
        self._fallback = fallback

    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume:
        try:
            return await self._primary.parse(content=content, content_type=content_type)
        except LlmParserError as exc:
            _log.warning("parse.llm-failed", error=str(exc), error_class=type(exc).__name__)
        except ParserError:
            # Extraction failure — permanent for the fallback too; re-raise.
            raise
        except Exception as exc:  # noqa: BLE001 — degradation boundary by design
            _log.warning("parse.llm-failed", error=str(exc), error_class=type(exc).__name__)
        return await self._fallback.parse(content=content, content_type=content_type)
```

Update `core/src/jobify/integrations/parser/__init__.py`: import + `__all__` entries for `FallbackResumeParser` and `LlmParserError` (alongside the existing names), and update the module docstring's "future LLM impl" sentence to name `llm_parser` and `fallback`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/unit/parser/test_fallback_parser.py -v`
Expected: 4 PASS.

- [ ] **Step 5: Gate + commit**

Run: `uv run pytest -m "not integration and not eval" -q && uv run mypy && uv run ruff check core/src api/src worker/src tests && uv run ruff format --check core/src api/src worker/src tests`

```bash
git add core/src/jobify/integrations/parser/ tests/unit/parser/
git commit -m "feat(parser): LlmParserError + FallbackResumeParser composite"
```

---

### Task 2: `GeminiResumeParser` (core)

**Files:**
- Create: `core/src/jobify/integrations/parser/llm_parser.py`
- Modify: `core/src/jobify/integrations/parser/__init__.py` (do NOT re-export the class at package level — that would import genai everywhere; leave `llm_parser` a leaf like `scoring/llm_explainer.py`)
- Test: `tests/unit/parser/test_llm_parser.py`

**Interfaces:**
- Consumes: `extract_text(*, content, content_type) -> str` from `jobify.integrations.parser.text`; `LlmParserError` from Task 1.
- Produces: `class GeminiResumeParser` with `__init__(self, *, client: GenaiClient, model: str)`, `async parse(self, *, content: bytes, content_type: str) -> ParsedResume`, and `async parse_text(self, text: str) -> ParsedResume` (the post-extraction path — Task 4's eval lane calls it directly). Constant `LLM_PARSER_NAME = "llm.gemini.v1"`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/parser/test_llm_parser.py`:

```python
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
    client.aio.models.generate_content = AsyncMock(
        return_value=SimpleNamespace(text=text)
    )
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/unit/parser/test_llm_parser.py -v`
Expected: FAIL — `ModuleNotFoundError: jobify.integrations.parser.llm_parser`.

- [ ] **Step 3: Implement `llm_parser.py`**

```python
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
        "skills": types.Schema(
            type=types.Type.ARRAY, items=types.Schema(type=types.Type.STRING)
        ),
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
        except (ValueError, ValidationError, TypeError) as exc:
            _log.debug("parse.llm-raw-output", raw_text=(raw or "")[:500])
            raise LlmParserError(f"llm_output_invalid: {exc}") from exc
        except Exception as exc:
            raise LlmParserError(f"llm_call_failed: {type(exc).__name__}") from exc
```

Note: pydantic v2's default `extra="ignore"` silently drops unknown keys in `ParsedResume(**payload)` — harmless, since `response_schema` already constrains the model's keys and the three reserved fields are popped explicitly. Type-invalid values raise `ValidationError` → first `except` arm → `LlmParserError`. `json.JSONDecodeError` is a `ValueError` subclass — also the first arm.

- [ ] **Step 4: Run tests to verify they pass**

Run: `uv run pytest tests/unit/parser/test_llm_parser.py -v`
Expected: 6 PASS.

- [ ] **Step 5: Gate + commit**

Run the four unit-side gates (pytest -m "not integration and not eval", mypy, ruff check, ruff format --check).

```bash
git add core/src/jobify/integrations/parser/llm_parser.py tests/unit/parser/test_llm_parser.py core/src/jobify/integrations/parser/__init__.py
git commit -m "feat(parser): GeminiResumeParser — structured-output Gemini parse over extracted text"
```

---

### Task 3: Worker settings + `get_resume_parser()` factory + parse-task swap

**Files:**
- Modify: `worker/src/jobify_worker/settings.py` (two fields, next to `match_explainer`)
- Modify: `worker/src/jobify_worker/runtime.py` (factory, after `get_match_explainer`)
- Modify: `worker/src/jobify_worker/tasks/parse.py` (swap hardcoded default)
- Modify: `worker/README.md` (config table rows) and `worker/CLAUDE.md` (invariant bullet)
- Test: `tests/unit/worker/test_resume_parser_factory.py` (create; mirror the dir layout of existing worker unit tests — find them with `ls tests/unit`), `tests/integration/test_parse_task.py` (append)

**Interfaces:**
- Consumes: `FallbackResumeParser`, `GeminiResumeParser`, `LibraryResumeParser` (Tasks 1–2).
- Produces: `WorkerSettings.resume_parser: Literal["library", "llm"] = "llm"`, `WorkerSettings.resume_parser_model: str = "gemini-2.5-flash"`; `jobify_worker.runtime.get_resume_parser() -> ResumeParser` (lazy singleton `_resume_parser`). Task 4+ never touch the worker again.

- [ ] **Step 1: Write the failing factory unit tests**

`tests/unit/worker/test_resume_parser_factory.py` (adjust import path to match the actual test-dir layout found above):

```python
"""get_resume_parser() selection matrix — no network, no real key."""

from __future__ import annotations

import pytest
from pydantic import SecretStr

import jobify_worker.runtime as runtime_mod
from jobify.integrations.parser.fallback import FallbackResumeParser
from jobify.integrations.parser.library import LibraryResumeParser


@pytest.fixture(autouse=True)
def _reset_singleton(monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setattr(runtime_mod, "_resume_parser", None)
    yield
    monkeypatch.setattr(runtime_mod, "_resume_parser", None)


def test_library_selection(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "library")
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, LibraryResumeParser)


def test_llm_selection_with_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "llm")
    monkeypatch.setattr(runtime_mod.settings, "gemini_api_key", SecretStr("k"))
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, FallbackResumeParser)


def test_llm_without_key_degrades_to_library(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "llm")
    monkeypatch.setattr(runtime_mod.settings, "gemini_api_key", None)
    parser = runtime_mod.get_resume_parser()
    assert isinstance(parser, LibraryResumeParser)


def test_singleton_cached(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runtime_mod.settings, "resume_parser", "library")
    assert runtime_mod.get_resume_parser() is runtime_mod.get_resume_parser()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/unit/worker/test_resume_parser_factory.py -v` (path adjusted)
Expected: FAIL — `AttributeError: ... has no attribute 'get_resume_parser'` / settings field missing.

- [ ] **Step 3: Implement settings + factory + swap**

`settings.py` — add directly under `match_explainer_model`:

```python
    resume_parser: Literal["library", "llm"] = "llm"
    resume_parser_model: str = "gemini-2.5-flash"
```

`runtime.py` — append after the match-explainer block:

```python
# --- Per-worker resume parser ---

_resume_parser: ResumeParser | None = None


def get_resume_parser() -> ResumeParser:
    """Return the worker's resume parser, building it lazily.

    Reads ``settings.resume_parser``:
    - ``"library"`` — ``LibraryResumeParser`` (deterministic, no network).
    - ``"llm"``     — ``FallbackResumeParser(GeminiResumeParser, LibraryResumeParser)``.

    Unlike ``get_match_explainer``, a missing Gemini key with ``"llm"`` selected
    degrades to the library parser with a warning instead of raising — the
    parser has a same-quality-as-today fallback, so keyless dev boots fine.
    Same monkeypatch-before-first-call contract as the other factories.
    """
    global _resume_parser
    if _resume_parser is None:
        if settings.resume_parser == "library":
            from jobify.integrations.parser.library import LibraryResumeParser

            _resume_parser = LibraryResumeParser()
        elif settings.resume_parser == "llm":
            if settings.gemini_api_key is None:
                from jobify.integrations.parser.library import LibraryResumeParser

                _log.warning("resume-parser.no-gemini-key-degrading-to-library")
                _resume_parser = LibraryResumeParser()
            else:
                from google import genai

                from jobify.integrations.parser.fallback import FallbackResumeParser
                from jobify.integrations.parser.library import LibraryResumeParser
                from jobify.integrations.parser.llm_parser import GeminiResumeParser

                _resume_parser = FallbackResumeParser(
                    primary=GeminiResumeParser(
                        client=genai.Client(
                            api_key=settings.gemini_api_key.get_secret_value(),
                            http_options=genai.types.HttpOptions(
                                timeout=int(settings.provider_read_timeout_seconds * 1000)
                            ),
                        ),
                        model=settings.resume_parser_model,
                    ),
                    fallback=LibraryResumeParser(),
                )
        else:
            raise ValueError(f"unknown resume_parser: {settings.resume_parser!r}")
    return _resume_parser
```

(`ResumeParser` needs importing in runtime.py's TYPE/imports section; `_log` and the api-key access pattern — check how `_gemini_api_key_or_raise` reads the secret and mirror the `get_secret_value()` usage. Match the module's existing import style.)

`tasks/parse.py` — replace the hardcoded default:

```python
    parser = parser or get_resume_parser()
```

with `from jobify_worker.runtime import get_resume_parser` added to the module's existing runtime imports (top-level or local — match how the file imports `get_session_maker`), and delete the now-unused `LibraryResumeParser` import if nothing else in the file uses it.

- [ ] **Step 4: Integration tests — provenance through the real task**

The parse-task integration tests live in `tests/integration/test_parse_task.py` (existing tests already inject `parser=` — `test_parse_happy_path_persists_parsed_json` is the template). Append two tests mirroring its setup verbatim, changing only the injected parser and assertions:

```python
class _FakeLlmParser:
    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume:
        return ParsedResume(parser_name="llm.gemini.v1", raw_text="fake", name="Fake Name")


class _AlwaysFailingPrimary:
    async def parse(self, *, content: bytes, content_type: str) -> ParsedResume:
        raise LlmParserError("llm_call_failed: Boom")


@pytest.mark.integration
async def test_parse_stores_llm_provenance(...existing fixture params...) -> None:
    # setup mirrors the neighboring happy-path test, but parser=_FakeLlmParser()
    ...
    assert resume.parsed_json["parser_name"] == "llm.gemini.v1"
    assert resume.parse_status == ResumeParseStatus.PARSED


@pytest.mark.integration
async def test_parse_falls_back_to_library_provenance(...) -> None:
    # parser=FallbackResumeParser(primary=_AlwaysFailingPrimary(), fallback=LibraryResumeParser())
    ...
    assert resume.parsed_json["parser_name"] == "library.v1"
    assert resume.parse_status == ResumeParseStatus.PARSED
```

(The `...existing fixture params...` are the file's own — copy the adjacent test's signature and body, changing only the injected parser and the assertions shown. The implementer must read that file first; its helpers already handle storage bytes + session.)

- [ ] **Step 5: Run tests**

Run: `uv run pytest tests/unit/worker/test_resume_parser_factory.py -v` then `uv run pytest tests/integration/ -k "parse" -v`
Expected: all PASS (plus every pre-existing parse test untouched and green).

- [ ] **Step 6: Docs**

`worker/README.md` — add to the env/config table (match its formatting):

```markdown
| `JOBIFY_RESUME_PARSER` | `llm` | Resume parser: `llm` (Gemini with library fallback) or `library` (deterministic, no network). Keyless + `llm` degrades to library with a warning. |
| `JOBIFY_RESUME_PARSER_MODEL` | `gemini-2.5-flash` | Gemini model for resume parsing. |
```

`worker/CLAUDE.md` — add one bullet to the parse-task section:

```markdown
- **Parser selection:** `get_resume_parser()` (runtime.py, explainer-precedent lazy singleton) — `llm` (default) = `FallbackResumeParser(GeminiResumeParser, LibraryResumeParser)`; ANY LLM failure degrades to library (`parse.llm-failed` log + `parser_name` provenance in the stored row), extraction `ParserError`s stay permanent. Keyless `llm` degrades to library at build time (no raise, unlike the explainer). `thinking_budget=0` + `max_output_tokens=8192` are load-bearing in `llm_parser.py`.
```

- [ ] **Step 7: Gate + commit**

Run the full backend gate (all six CI commands).

```bash
git add worker/ core/ tests/
git commit -m "feat(worker): env-selected resume parser factory with library fallback"
```

---

### Task 4: Eval `parse_fn` seam + LLM-lane eval test

**Files:**
- Modify: `core/src/jobify/eval/parse_f1.py` (`eval_gold_dataset` signature)
- Modify: `tests/eval/test_parse_f1_gate.py` (add the LLM-lane test)
- Test: `tests/unit/eval/test_parse_f1_seam.py` (create; mirror unit-dir layout)

**Interfaces:**
- Consumes: `GeminiResumeParser.parse_text(text) -> ParsedResume` (Task 2).
- Produces: `eval_gold_dataset(data_dir: Path | None = None, parse_fn: Callable[[str], ParsedResume] | None = None) -> EvalReport` — `parse_fn` defaults to the library `_parse_text_only`. Task 6's report generation calls it with the Gemini lane.

- [ ] **Step 1: Write the failing seam test**

`tests/unit/eval/test_parse_f1_seam.py`:

```python
"""eval_gold_dataset parse_fn seam — scoring is parser-agnostic."""

from __future__ import annotations

from jobify.eval.parse_f1 import eval_gold_dataset
from jobify.integrations.parser import ParsedResume


def test_parse_fn_seam_perfect_parser_scores_1() -> None:
    """A parse_fn that echoes each example's expected fields scores F1=1.0."""
    import json
    from pathlib import Path

    data_dir = Path("core/data/parse_eval")
    expected_by_text: dict[str, dict] = {}
    for txt in data_dir.glob("*.txt"):
        exp = txt.with_suffix(".expected.json")
        if exp.exists():
            expected_by_text[txt.read_text(encoding="utf-8")] = json.loads(
                exp.read_text(encoding="utf-8")
            )

    def perfect(text: str) -> ParsedResume:
        e = expected_by_text[text]
        return ParsedResume(
            parser_name="perfect.eval",
            raw_text=text,
            name=e.get("name"),
            email=e.get("email"),
            phone=e.get("phone"),
            skills=e.get("skills", []),
        )

    report = eval_gold_dataset(parse_fn=perfect)
    assert report.overall_f1 == 1.0


def test_default_parse_fn_unchanged_library_path() -> None:
    """No parse_fn -> identical report to the pre-seam library behavior."""
    report = eval_gold_dataset()
    assert report.overall_f1 > 0  # library lane still runs end-to-end
```

- [ ] **Step 2: Run to verify it fails**

Run: `uv run pytest tests/unit/eval/test_parse_f1_seam.py -v`
Expected: FAIL — `TypeError: eval_gold_dataset() got an unexpected keyword argument 'parse_fn'`.

- [ ] **Step 3: Implement the seam**

In `parse_f1.py`: add `from collections.abc import Callable` to imports; change the signature and the one call site:

```python
def eval_gold_dataset(
    data_dir: Path | None = None,
    parse_fn: Callable[[str], ParsedResume] | None = None,
) -> EvalReport:
    """Score a parser against the gold dataset and return the F1 report.

    ``parse_fn`` maps raw text to a ParsedResume; defaults to the library
    parser's text-only heuristics. The LLM eval lane passes a Gemini-backed
    fn — scoring and normalization are parser-agnostic.
    """
    parse_fn = parse_fn or _parse_text_only
```

and inside the loop replace `parsed = _parse_text_only(text)` with `parsed = parse_fn(text)`. Update the module docstring's first line ("F1 scoring for resume parsers against the gold dataset").

- [ ] **Step 4: Add the LLM-lane eval test**

Append to `tests/eval/test_parse_f1_gate.py`:

```python
LLM_OVERALL_FLOOR = 0.90


def _llm_lane_enabled() -> bool:
    import os

    return (
        os.environ.get("JOBIFY_PARSE_EVAL_PARSER") == "llm"
        and bool(os.environ.get("JOBIFY_GEMINI_API_KEY"))
    )


@pytest.mark.skipif(
    not _llm_lane_enabled(),
    reason="LLM lane: set JOBIFY_PARSE_EVAL_PARSER=llm + JOBIFY_GEMINI_API_KEY (never runs in CI)",
)
def test_llm_parser_meets_quality_gate() -> None:
    """On-demand lane — live Gemini. The committed LLM_EVAL_REPORT.md is the
    durable record; this test is the measurement.

    Run: JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s
    """
    import asyncio
    import os

    from google import genai

    from jobify.integrations.parser.llm_parser import GeminiResumeParser

    client = genai.Client(api_key=os.environ["JOBIFY_GEMINI_API_KEY"])
    parser = GeminiResumeParser(
        client=client,
        model=os.environ.get("JOBIFY_RESUME_PARSER_MODEL", "gemini-2.5-flash"),
    )

    report = eval_gold_dataset(parse_fn=lambda text: asyncio.run(parser.parse_text(text)))

    print()
    print(report.summary())
    print()
    print(report.example_breakdown())

    failures: list[str] = []
    for field_name, floor in PER_FIELD_FLOORS.items():
        f1 = report.per_field_f1[field_name]
        if f1 < floor:
            failures.append(f"{field_name}: F1={f1:.3f} below floor {floor}")
    if report.overall_f1 < LLM_OVERALL_FLOOR:
        failures.append(
            f"overall: F1={report.overall_f1:.3f} below LLM floor {LLM_OVERALL_FLOOR}"
        )
    assert not failures, "LLM parse F1 gate violated:\n  " + "\n  ".join(failures)
```

- [ ] **Step 5: Run tests**

Run: `uv run pytest tests/unit/eval/test_parse_f1_seam.py -v && uv run pytest -m eval -s` (no env vars → library gate runs, LLM test SKIPS with the reason string).
Expected: seam tests PASS; eval lane shows `1 passed, 1 skipped`.

- [ ] **Step 6: Gate + commit**

Full unit-side gates.

```bash
git add core/src/jobify/eval/parse_f1.py tests/eval/test_parse_f1_gate.py tests/unit/eval/
git commit -m "feat(eval): parse_fn seam + on-demand LLM parse-F1 lane (>=0.90)"
```

---

### Task 5: Gold dataset growth 8 → 20

**Files:**
- Create: `core/data/parse_eval/009-*.txt` + `.expected.json` … `020-*.txt` + `.expected.json` (12 pairs)
- Modify: `core/data/parse_eval/000_README.md` (documented-limitations section if needed)
- Modify: `core/CLAUDE.md` (dataset-size mention in the Parse F1 section, if it states a count)

**Interfaces:**
- Consumes: nothing from other tasks (pure data). The library CI gate (floors + 0.85) constrains it.
- Produces: the 20-example dataset Task 6 measures against.

- [ ] **Step 1: Read the substrate**

Read `core/data/parse_eval/000_README.md` and two existing pairs (e.g. `001-*`, `004-*`) to copy the exact expected.json key shape (`name`/`email`/`phone`/`skills` — check whether experience/education appear; only the four gated fields need expectations, mirror what existing files include). Read `core/src/jobify/integrations/parser/library.py`'s `_extract_skills`/`_extract_name` to understand what "hard for the library parser" means concretely.

- [ ] **Step 2: Author the 12 pairs — .txt FIRST, expected.json derived by reading it**

Authoring procedure per example (data-contract rule): write the resume `.txt` in full first; then open it and transcribe the expected values by reading the text — never from the persona sketch. Personas (id — persona — difficulty features):

- `009-meera-sales-manager` — 8y FMCG sales manager, non-tech — skills that aren't in a tech skills dictionary (distribution, channel sales), name under a "PROFILE" header.
- `010-tabular-devjyoti-qa` — QA engineer whose PDF-extracted text is a mangled two-column artifact (interleaved fragments, e.g. contact block split across lines mid-token).
- `011-anand-career-gap` — developer with a 3-year gap and a "Career Break (2019–2022)" entry; return role after.
- `012-fresher-projects-riya` — projects-only fresher: no experience section at all, GitHub projects with tech lists.
- `013-suresh-ops-executive` — operations executive, 4y, plain prose, phone written as `98450 12345` (no +91).
- `014-kavitha-teacher` — school teacher, 12y, education-heavy, B.Ed + M.A., no skills section (skills mentioned inline in prose).
- `015-rahul-senior-architect` — 16y staff/architect, long multi-role history at 5 companies, several stacks — long-document stress.
- `016-hinglish-pooja-hr` — HR generalist with mixed Hindi-English phrasing ("payroll dekhna", "team ko manage kiya") around English section headers.
- `017-unconventional-headers-dev` — backend dev using headers like "Where I've Worked" / "Things I'm Good At" / "Papers & Badges".
- `018-certs-heavy-cloudops` — cloud engineer with 9 certifications (AWS/GCP/K8s) and a thin experience section.
- `019-phone-only-imran` — delivery-operations lead with NO email anywhere; phone-only contact block (expected.json: `"email": null`).
- `020-name-midheader-lakshmi` — resume opening with a decorative line, then `== Resume of Lakshmi Venkatesan ==` mid-header; email in the footer.

Keep each `.txt` realistic (300–900 words), Indian-market flavored (₹ CTC mentions, Indian cities), plain UTF-8. `expected.json` contains exactly the keys the existing files use.

- [ ] **Step 3: Run the library gate after authoring**

Run: `uv run pytest -m eval -s`
The library gate (0.85 + floors) MUST still pass on all 20. The hard cases will lower per-example scores — that is the point — but the aggregate must hold. If a floor or the overall dips: first re-read the failing example's expectation against its text (fix transcription errors); then, if the expectation is correct and the library parser genuinely can't hit it, either (a) rebalance that example's difficulty (e.g. keep the mangled layout but give it a clean email line), or (b) if the failure is isolated to non-gated fields, document the limitation in `000_README.md`. Never edit floors, never delete an example silently — swaps/rebalances are listed in the commit message.

- [ ] **Step 4: Update docs**

`000_README.md`: bump any stated count to 20, add one line per documented limitation (if any). `core/CLAUDE.md`'s "Parse F1 quality gate" section: no count is stated there today — only touch it if Step 3 produced a documented limitation worth pinning.

- [ ] **Step 5: Gate + commit**

Run: `uv run pytest -m eval -s` (green) + `uv run ruff format --check core/src api/src worker/src tests` (data files aren't linted, but run the full unit gate anyway to be safe).

```bash
git add core/data/parse_eval/ core/CLAUDE.md
git commit -m "feat(eval): grow parse gold dataset 8 -> 20 with hard cases"
```

---

### Task 6: LLM-lane measurement + committed report

**Files:**
- Create: `core/data/parse_eval/LLM_EVAL_REPORT.md`

**Interfaces:**
- Consumes: the seam (Task 4), the 20-example dataset (Task 5), a real `JOBIFY_GEMINI_API_KEY` from the repo-root `.env`.

- [ ] **Step 1: Run the LLM lane live**

Run: `JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm`
(`.env` at repo root carries `JOBIFY_GEMINI_API_KEY`; never echo the key.)
Expected: the LLM test RUNS (not skipped) and prints the full report.

- [ ] **Step 2: If overall < 0.90 — ONE bounded iteration**

Allowed levers, in order: (a) prompt wording in `_SYSTEM_INSTRUCTION` (e.g. clarify skills granularity if the skills field is the laggard — set-F1 punishes over-splitting); (b) verify the laggard examples' expectations against their text one more time. NOT allowed: editing floors, cherry-deleting hard examples, raising temperature. Re-run the lane after each change. If after one full iteration the lane still misses 0.90, STOP and report the numbers — the gate decision (more iterations vs. dataset review) goes back to the user.

- [ ] **Step 3: Write the committed report**

Generate `core/data/parse_eval/LLM_EVAL_REPORT.md` from the passing run's output:

```markdown
# LLM parse-F1 eval report

- Date: <run date>
- Model: gemini-2.5-flash
- Dataset: 20 examples (001–020)
- Command: `JOBIFY_PARSE_EVAL_PARSER=llm uv run --env-file=.env pytest -m eval -s -k llm`

## Result: overall F1 = <value> (gate ≥ 0.90) — PASS

<paste report.summary() verbatim>

## Per-example breakdown

<paste report.example_breakdown() verbatim>

Re-run and refresh this file after any prompt, model, or dataset change.
```

- [ ] **Step 4: Verify the library lane still passes + commit**

Run: `uv run pytest -m eval -s` (library green, LLM skipped without env).

```bash
git add core/data/parse_eval/LLM_EVAL_REPORT.md core/src/jobify/integrations/parser/llm_parser.py
git commit -m "feat(eval): LLM-lane parse-F1 report — acceptance record for the 0.90 gate"
```

(Include `llm_parser.py` only if Step 2 changed the prompt.)

---

### Task 7: Core CLAUDE.md + full gates

**Files:**
- Modify: `core/CLAUDE.md` (parser section bullet)

- [ ] **Step 1: Pin the invariants**

Add to `core/CLAUDE.md`'s "Parse F1 quality gate" section (or a new "LLM resume parser" bullet directly above it):

```markdown
- **LLM parser (spec `2026-08-01-llm-resume-parsing-design.md`):** `parser/llm_parser.py` is the ONLY module importing `google.genai` in the parser package — never re-export `GeminiResumeParser` from `parser/__init__` (would drag genai into every import). `thinking_budget=0` + `max_output_tokens=8192` are load-bearing (explainer starvation precedent). `LlmParserError(ParserError)` = post-extraction LLM failure; `FallbackResumeParser` catches it (and any non-ParserError) → library fallback + `parse.llm-failed` log; plain extraction `ParserError`s propagate (permanent for any parser). Two eval lanes: CI = library at 0.85 (deterministic); acceptance 0.90 = on-demand LLM lane, record committed at `core/data/parse_eval/LLM_EVAL_REPORT.md` — refresh it in the same commit as any prompt/model/dataset change.
```

- [ ] **Step 2: Full CI-verbatim gate**

Run all six backend commands from Global Constraints.
Expected: all green (LLM eval test skipped — that's the designed CI behavior).

- [ ] **Step 3: Commit**

```bash
git add core/CLAUDE.md
git commit -m "docs(core): pin LLM resume parser + two-lane eval invariants"
```
