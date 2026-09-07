"""F1 scoring for resume parsers against the gold datasets.

Two kinds of field:

**Gated** (drive ``overall`` and the CI / acceptance floors):
- ``name`` (scalar)
- ``email`` (scalar, lowercased)
- ``phone`` (scalar, digits-only)
- ``skills`` (set)

**Report-only** (printed, never gate — added 2026-09-07; floors get set from
a measured baseline in a follow-up, never before one exists):
- ``languages`` (set) — human languages, never programming languages
- ``experience`` (set of ``company|title`` keys)
- ``education`` (set of ``institution|degree`` keys)
- ``certifications`` (set of ``name`` keys)

Structured lists score by **normalised exact match on a key** (case-fold,
whitespace collapse, trailing punctuation stripped; a missing part is ``?``).
Gold entries are authored to the resume's own wording and the LLM prompt says
copy verbatim, so exact-after-normalisation is the contract; fuzzy matching
was rejected because every threshold is an argument and hides exactly the
sloppiness the number should expose. Dates are not scored in v1.

Per-example contributions accumulate into per-field (TP, FP, FN) totals.
Per-field F1 = 2*TP / (2*TP + FP + FN). ``overall`` is the unweighted mean of
the GATED per-field F1s only — macro-averaging so a field with a handful of
relevant items isn't drowned out by skills, and so adding report-only fields
never moves the number the 0.85 / 0.90 floors were set against.

Two datasets:
- **Synthetic gold** (``core/data/parse_eval``, committed): ``<id>.txt`` +
  ``<id>.expected.json``.
- **Real set** (``sample_resume/`` at the repo root, gitignored — real
  applicants' PII): ``<name>.pdf|.docx`` + ``<name>.expected.json``, text
  extracted via the production ``extract_text``. Loaded only when the folder
  exists, so CI and other machines see the synthetic set alone. Callers must
  print **aggregate counts only** for it — never token diffs.
"""

from __future__ import annotations

import json
import os
from collections.abc import Callable, Iterable, Mapping
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Final, TypedDict

import anyio

from jobify.integrations.parser.base import ParsedResume
from jobify.integrations.parser.library import (
    _extract_email,
    _extract_name,
    _extract_phone,
    _extract_skills,
)
from jobify.integrations.parser.text import (
    DOCX_CONTENT_TYPE,
    PDF_CONTENT_TYPE,
    extract_text,
)

GATED_FIELDS: Final[tuple[str, ...]] = ("name", "email", "phone", "skills")
REPORT_ONLY_FIELDS: Final[tuple[str, ...]] = (
    "languages",
    "experience",
    "education",
    "certifications",
)
ALL_FIELDS: Final[tuple[str, ...]] = GATED_FIELDS + REPORT_ONLY_FIELDS


class _ExpectedExample(TypedDict, total=False):
    name: str | None
    email: str | None
    phone: str | None
    skills: list[str]
    languages: list[str]
    experience: list[dict[str, Any]]
    education: list[dict[str, Any]]
    certifications: list[dict[str, Any]]


Example = tuple[str, str, _ExpectedExample]
"""``(example_id, raw_text, expected)``."""

_REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_DATA_DIR = Path(__file__).resolve().parents[3] / "data" / "parse_eval"
DEFAULT_REAL_DATA_DIR = _REPO_ROOT / "sample_resume"
REAL_DATA_DIR_ENV: Final[str] = "JOBIFY_PARSE_EVAL_REAL_DIR"

_DOCUMENT_CONTENT_TYPES: Final[dict[str, str]] = {
    ".pdf": PDF_CONTENT_TYPE,
    ".docx": DOCX_CONTENT_TYPE,
}


# --- normalisation ---------------------------------------------------------


def _normalize_name(value: str | None) -> str | None:
    if value is None:
        return None
    return " ".join(value.casefold().split())


def _normalize_email(value: str | None) -> str | None:
    if value is None:
        return None
    return value.strip().casefold()


def _normalize_phone(value: str | None) -> str | None:
    if value is None:
        return None
    digits = "".join(ch for ch in value if ch.isdigit())
    return digits or None


def _normalize_skill_set(values: list[str]) -> set[str]:
    return {v.strip().casefold() for v in values if v.strip()}


def _normalize_key_part(value: object) -> str:
    """One component of a structured-entry key; ``?`` when absent."""
    if value is None:
        return "?"
    text = " ".join(str(value).casefold().split()).strip(" .,;:")
    return text or "?"


def _entry_get(entry: Any, name: str) -> object:
    """Read ``name`` from a pydantic entry (parsed) or a dict (expected)."""
    if isinstance(entry, Mapping):
        return entry.get(name)
    return getattr(entry, name, None)


def _entry_keys(entries: Iterable[Any], *parts: str) -> set[str]:
    keys: set[str] = set()
    for entry in entries:
        key = "|".join(_normalize_key_part(_entry_get(entry, part)) for part in parts)
        if key.replace("|", "").replace("?", ""):
            keys.add(key)
    return keys


def _experience_keys(entries: Iterable[Any]) -> set[str]:
    return _entry_keys(entries, "company", "title")


def _education_keys(entries: Iterable[Any]) -> set[str]:
    return _entry_keys(entries, "institution", "degree")


def _certification_keys(entries: Iterable[Any]) -> set[str]:
    return _entry_keys(entries, "name")


# --- counting --------------------------------------------------------------


@dataclass
class Counts:
    tp: int = 0
    fp: int = 0
    fn: int = 0

    def add(self, other: Counts) -> None:
        self.tp += other.tp
        self.fp += other.fp
        self.fn += other.fn

    def f1(self) -> float:
        denom = 2 * self.tp + self.fp + self.fn
        if denom == 0:
            return 1.0
        return (2 * self.tp) / denom


def _score_scalar(predicted: str | None, expected: str | None) -> Counts:
    if predicted is None and expected is None:
        return Counts()
    if predicted is None and expected is not None:
        return Counts(fn=1)
    if predicted is not None and expected is None:
        return Counts(fp=1)
    if predicted == expected:
        return Counts(tp=1)
    # Both non-null but mismatch — counts as both a missed expectation
    # AND a wrong prediction.
    return Counts(fp=1, fn=1)


def _score_set(predicted: set[str], expected: set[str]) -> Counts:
    return Counts(
        tp=len(predicted & expected),
        fp=len(predicted - expected),
        fn=len(expected - predicted),
    )


@dataclass
class ExampleResult:
    example_id: str
    per_field: dict[str, Counts]
    parsed_name: str | None
    parsed_email: str | None
    parsed_phone: str | None
    parsed_skills: list[str]
    expected_name: str | None
    expected_email: str | None
    expected_phone: str | None
    expected_skills: list[str]
    # Set-field token diffs (FP tokens, FN tokens) after normalisation — the
    # only way to tell "the model invented an entry" from "the gold file
    # omits a token the resume states". Printed for the synthetic set; for
    # the real set callers print counts only (PII).
    diffs: dict[str, tuple[list[str], list[str]]] = field(default_factory=dict)

    def overall_f1(self) -> float:
        gated = [c.f1() for name, c in self.per_field.items() if name in GATED_FIELDS]
        return sum(gated) / len(gated) if gated else 0.0


@dataclass
class EvalReport:
    examples: list[ExampleResult]
    per_field_totals: dict[str, Counts] = field(default_factory=dict)
    label: str = "gold dataset"

    @property
    def per_field_f1(self) -> dict[str, float]:
        return {name: c.f1() for name, c in self.per_field_totals.items()}

    @property
    def overall_f1(self) -> float:
        """Mean of the GATED fields' F1 only (see module docstring)."""
        f1s = [f1 for name, f1 in self.per_field_f1.items() if name in GATED_FIELDS]
        return sum(f1s) / len(f1s) if f1s else 0.0

    def summary(self) -> str:
        lines = [f"Parse F1 eval — {self.label} ({len(self.examples)} examples):"]
        for name in ALL_FIELDS:
            if name not in self.per_field_totals:
                continue
            c = self.per_field_totals[name]
            tag = "" if name in GATED_FIELDS else "  [report-only]"
            lines.append(f"  {name:<14} F1={c.f1():.3f}  (TP={c.tp}, FP={c.fp}, FN={c.fn}){tag}")
        lines.append(f"  {'overall':<14} F1={self.overall_f1:.3f}  (gated fields only)")
        return "\n".join(lines)

    def example_breakdown(self) -> str:
        lines = ["Per-example F1 (gated fields):"]
        for ex in self.examples:
            lines.append(f"  {ex.example_id}  F1={ex.overall_f1():.3f}")
            for fname, c in ex.per_field.items():
                lines.append(f"    {fname:<14} F1={c.f1():.3f}  TP={c.tp} FP={c.fp} FN={c.fn}")
        return "\n".join(lines)

    def token_diff(self) -> str:
        """Every set-field FP/FN token per example. Synthetic set ONLY —
        for real resumes this would print employers and credentials."""
        lines = ["Token diff (FP = predicted but not expected, FN = expected but not predicted):"]
        for ex in self.examples:
            for fname, (fp, fn) in ex.diffs.items():
                if fp or fn:
                    lines.append(f"  {ex.example_id}  {fname}  FP={fp}  FN={fn}")
        return "\n".join(lines)


# --- parsers + datasets ------------------------------------------------------


def _parse_text_only(text: str) -> ParsedResume:
    """Run the library parser's extraction heuristics directly on a text string.

    Bypasses ``LibraryResumeParser.parse`` (which invokes ``extract_text``
    on bytes). The F1 gate is testing extraction quality, not the
    byte->text step.
    """
    return ParsedResume(
        parser_name="library.v1.eval",
        raw_text=text,
        name=_extract_name(text),
        email=_extract_email(text),
        phone=_extract_phone(text),
        skills=_extract_skills(text),
    )


def _load_examples(data_dir: Path) -> list[Example]:
    """Return list of (example_id, raw_text, expected_dict).

    Pairs each ``<id>.txt`` with the matching ``<id>.expected.json``. Skips
    the README and any orphan files.
    """
    examples: list[Example] = []
    for txt_path in sorted(data_dir.glob("*.txt")):
        expected_path = txt_path.with_suffix(".expected.json")
        if not expected_path.exists():
            continue
        raw_text = txt_path.read_text(encoding="utf-8")
        expected: _ExpectedExample = json.loads(expected_path.read_text(encoding="utf-8"))
        examples.append((txt_path.stem, raw_text, expected))
    return examples


async def _extract_document_text(content: bytes, content_type: str) -> str:
    """Positional shim: ``anyio.run`` forwards *args only."""
    return await extract_text(content=content, content_type=content_type)


def load_document_examples(data_dir: Path) -> list[Example]:
    """Real-resume examples: ``<name>.pdf|.docx`` + ``<name>.expected.json``.

    Text comes from the production ``extract_text`` so the number describes
    what the pipeline actually feeds the parser (including the byte->text
    step this time — that is the point of the real set). Documents without
    an expected file are skipped, so a half-authored folder still runs.
    """
    examples: list[Example] = []
    for doc_path in sorted(data_dir.iterdir()):
        content_type = _DOCUMENT_CONTENT_TYPES.get(doc_path.suffix.lower())
        if content_type is None:
            continue
        expected_path = doc_path.with_suffix(".expected.json")
        if not expected_path.exists():
            continue
        raw_text = anyio.run(_extract_document_text, doc_path.read_bytes(), content_type)
        expected: _ExpectedExample = json.loads(expected_path.read_text(encoding="utf-8"))
        examples.append((doc_path.stem, raw_text, expected))
    return examples


def real_data_dir() -> Path | None:
    """The real-set folder if it exists locally, else None (CI, other machines)."""
    override = os.environ.get(REAL_DATA_DIR_ENV)
    candidate = Path(override).expanduser() if override else DEFAULT_REAL_DATA_DIR
    return candidate if candidate.is_dir() else None


def real_examples() -> list[Example]:
    """Real-set examples when the folder is present, else ``[]``."""
    data_dir = real_data_dir()
    return load_document_examples(data_dir) if data_dir else []


# --- evaluation --------------------------------------------------------------


def score_example(
    example_id: str, parsed: ParsedResume, expected: _ExpectedExample
) -> ExampleResult:
    per_field: dict[str, Counts] = {}
    diffs: dict[str, tuple[list[str], list[str]]] = {}

    per_field["name"] = _score_scalar(
        _normalize_name(parsed.name), _normalize_name(expected.get("name"))
    )
    per_field["email"] = _score_scalar(
        _normalize_email(parsed.email), _normalize_email(expected.get("email"))
    )
    per_field["phone"] = _score_scalar(
        _normalize_phone(parsed.phone), _normalize_phone(expected.get("phone"))
    )

    set_pairs: dict[str, tuple[set[str], set[str]]] = {
        "skills": (
            _normalize_skill_set(parsed.skills),
            _normalize_skill_set(expected.get("skills", [])),
        ),
        "languages": (
            _normalize_skill_set(parsed.languages),
            _normalize_skill_set(expected.get("languages", [])),
        ),
        "experience": (
            _experience_keys(parsed.experience),
            _experience_keys(expected.get("experience", [])),
        ),
        "education": (
            _education_keys(parsed.education),
            _education_keys(expected.get("education", [])),
        ),
        "certifications": (
            _certification_keys(parsed.certifications),
            _certification_keys(expected.get("certifications", [])),
        ),
    }
    for fname, (predicted, wanted) in set_pairs.items():
        per_field[fname] = _score_set(predicted, wanted)
        diffs[fname] = (sorted(predicted - wanted), sorted(wanted - predicted))

    return ExampleResult(
        example_id=example_id,
        per_field=per_field,
        parsed_name=parsed.name,
        parsed_email=parsed.email,
        parsed_phone=parsed.phone,
        parsed_skills=list(parsed.skills),
        expected_name=expected.get("name"),
        expected_email=expected.get("email"),
        expected_phone=expected.get("phone"),
        expected_skills=list(expected.get("skills", [])),
        diffs=diffs,
    )


def eval_examples(
    examples: list[Example],
    parse_fn: Callable[[str], ParsedResume],
    *,
    label: str = "gold dataset",
) -> EvalReport:
    """Score ``parse_fn`` over ``examples`` — the dataset-agnostic core."""
    if not examples:
        raise RuntimeError(f"no examples to evaluate for {label}")
    per_field_totals: dict[str, Counts] = {name: Counts() for name in ALL_FIELDS}
    results: list[ExampleResult] = []
    for example_id, text, expected in examples:
        result = score_example(example_id, parse_fn(text), expected)
        for k, counts in result.per_field.items():
            per_field_totals[k].add(counts)
        results.append(result)
    return EvalReport(examples=results, per_field_totals=per_field_totals, label=label)


def eval_gold_dataset(
    data_dir: Path | None = None,
    parse_fn: Callable[[str], ParsedResume] | None = None,
) -> EvalReport:
    """Score a parser against the synthetic gold dataset and return the report.

    ``parse_fn`` maps raw text to a ParsedResume; defaults to the library
    parser's text-only heuristics. The LLM eval lane passes a Gemini-backed
    fn — scoring and normalization are parser-agnostic.
    """
    data_dir = data_dir or DEFAULT_DATA_DIR
    examples = _load_examples(data_dir)
    if not examples:
        raise RuntimeError(f"no gold examples found in {data_dir}")
    return eval_examples(examples, parse_fn or _parse_text_only, label="synthetic gold")
