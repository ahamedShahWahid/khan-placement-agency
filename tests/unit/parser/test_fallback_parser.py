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
