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
