"""Resume parser interface + concrete implementations.

The Protocol + ParsedResume schema live in :mod:`.base`. The library/regex
implementation is in :mod:`.library`. The Gemini-backed implementation lives in
:mod:`.llm_parser` behind the same Protocol — it is a leaf module that imports
``google.genai`` and is never re-exported from this package (would drag genai
into every import). The fallback composite (LLM primary, library recovery) is
in :mod:`.fallback`.
"""

from jobify.integrations.parser.base import (
    CertificationEntry,
    EducationEntry,
    ExperienceEntry,
    LlmParserError,
    ParsedResume,
    ParserError,
    ResumeParser,
    TransientParserError,
)
from jobify.integrations.parser.fallback import FallbackResumeParser

__all__ = [
    "CertificationEntry",
    "EducationEntry",
    "ExperienceEntry",
    "FallbackResumeParser",
    "LlmParserError",
    "ParsedResume",
    "ParserError",
    "ResumeParser",
    "TransientParserError",
]
