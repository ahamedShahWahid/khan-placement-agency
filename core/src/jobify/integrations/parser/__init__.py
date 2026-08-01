"""Resume parser interface + concrete implementations.

The Protocol + ParsedResume schema live in :mod:`.base`. The library/regex
implementation is in :mod:`.library`. The fallback composite is in :mod:`.fallback`.
A future LLM-backed impl will land in :mod:`.llm_parser` behind the same Protocol
once the provider decision (spec §14 #1) is resolved.
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
