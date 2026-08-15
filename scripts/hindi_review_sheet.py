#!/usr/bin/env python3
"""Build a native-speaker review sheet for the app's Hindi strings.

Pairs every string in ``app/lib/l10n/app_en.arb`` with its ``app_hi.arb``
counterpart, grouped by screen, and writes a self-contained HTML page. The
page is meant to be published as an Artifact (or printed -- it has a ruled
correction gutter in the print stylesheet) and handed to a Hindi speaker.

Why a script and not a one-off: the string set changes with every feature,
and a review sheet is only useful if it reflects what actually ships. Re-run
after touching the ARBs.

    uv run python scripts/hindi_review_sheet.py [-o out.html]

Two signals are computed rather than left to the reviewer's eye:

* **Value slots.** ``{placeholder}`` tokens are rendered as chips in BOTH
  columns. A translation that drops, renames or invents one crashes that
  screen at runtime, so it must survive verbatim -- that is a correctness
  bug a prose reviewer would skim straight past.
* **Untranslated strings.** Rows whose Hindi is byte-identical to the
  English are flagged. Many are legitimate (a wordmark, a currency prefix)
  but city names have common Devanagari spellings, and only a native speaker
  can say which way each should go.

Exits non-zero if the two files disagree on which keys exist or on any
string's placeholder set -- those are build errors, not review notes.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
L10N_DIR = REPO_ROOT / "app" / "lib" / "l10n"
TEMPLATE = Path(__file__).resolve().parent / "hindi_review_template.html"

# Longest prefix wins, so order matters: `feedCity` must precede `feed`.
GROUPS: tuple[tuple[str, str], ...] = (
    ("shell", "Navigation"),
    ("common", "Shared words & errors"),
    ("auth", "Sign-in"),
    ("onboarding", "Employer onboarding"),
    ("feedCity", "City names"),
    ("feedFilter", "Feed filters"),
    ("feedSummary", "Feed summary tiles"),
    ("feed", "Feed"),
    ("match", "Match explanation"),
    ("jobDetail", "Job detail"),
    ("saved", "Saved jobs"),
    ("stage", "Application stages"),
    ("applications", "Applications"),
    ("notification", "Notifications"),
    ("privacy", "Privacy & consent"),
    ("deleteAccount", "Delete account"),
    ("resume", "Resume"),
    ("preferences", "Job preferences"),
    ("desiredRole", "Role categories"),
    ("editProfile", "Edit profile"),
    ("profile", "Profile"),
    ("invites", "Team invites"),
    ("form", "Forms"),
)

_PLACEHOLDER_RE = re.compile(r"\{(\w+)\}")


def _placeholders(text: str) -> list[str]:
    return _PLACEHOLDER_RE.findall(text or "")


def _group_of(key: str) -> str:
    for prefix, label in GROUPS:
        if key.startswith(prefix):
            return label
    return "Other"


def _render(text: str) -> str:
    """Escape, then mark up placeholders as chips."""
    return _PLACEHOLDER_RE.sub(r'<code class="ph">{\1}</code>', html.escape(text or ""))


def _slug(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")


def build(en: dict[str, str], hi: dict[str, str]) -> str:
    keys = [k for k in en if not k.startswith("@")]

    buckets: dict[str, list[str]] = {}
    for key in keys:
        buckets.setdefault(_group_of(key), []).append(key)

    order = [label for _p, label in GROUPS if label in buckets]
    # dedupe while preserving order (several prefixes may share a label)
    order = list(dict.fromkeys(order))
    if "Other" in buckets:
        order.append("Other")

    nav: list[str] = []
    rows: list[str] = []
    for label in order:
        group_keys = buckets[label]
        slug = _slug(label)
        same_count = sum(1 for k in group_keys if en[k] == hi.get(k))
        nav.append(
            f'<li><a href="#{slug}">{html.escape(label)}'
            f'<span class="navct">{len(group_keys)}</span></a></li>'
        )
        plural = "s" if len(group_keys) != 1 else ""
        meta = f"{len(group_keys)} string{plural}"
        if same_count:
            meta += f" &middot; {same_count} in English"
        rows.append(
            f'<section id="{slug}" class="grp"><h2>{html.escape(label)}'
            f'<span class="grpmeta">{meta}</span></h2>'
        )
        for key in group_keys:
            english, hindi = en[key], hi.get(key, "")
            description = (en.get("@" + key) or {}).get("description", "")
            flags: list[str] = []
            slots = _placeholders(english)
            if slots:
                chips = ", ".join(f"<code>{{{name}}}</code>" for name in slots)
                flags.append(f'<span class="flag flag-ph">keeps {chips}</span>')
            if english == hindi:
                flags.append(
                    '<span class="flag flag-same">same as English '
                    "&mdash; confirm intended</span>"
                )
            desc_html = f'<p class="desc">{html.escape(description)}</p>' if description else ""
            rows.append(
                f'<article class="row{" is-same" if english == hindi else ""}">\n'
                f'  <div class="rowhead"><code class="key">{html.escape(key)}</code>'
                f"{''.join(flags)}{desc_html}</div>\n"
                f'  <div class="pair">\n'
                f'    <div class="cell en"><span class="lang">EN</span>'
                f"<p>{_render(english)}</p></div>\n"
                f'    <div class="cell hi"><span class="lang">HI</span>'
                f'<p lang="hi">{_render(hindi)}</p></div>\n'
                f"  </div>\n"
                f'  <div class="fix"></div>\n'
                f"</article>"
            )
        rows.append("</section>")

    return (
        TEMPLATE.read_text()
        .replace("<!--NAV-->", "\n".join(nav))
        .replace("<!--ROWS-->", "\n".join(rows))
        .replace("{{TOTAL}}", str(len(keys)))
        .replace("{{NPH}}", str(sum(1 for k in keys if _placeholders(en[k]))))
        .replace("{{NSAME}}", str(sum(1 for k in keys if en[k] == hi.get(k))))
        .replace("{{NGRP}}", str(len(order)))
    )


def check(en: dict[str, str], hi: dict[str, str]) -> list[str]:
    """Build errors -- not review notes. These block the sheet."""
    problems: list[str] = []
    en_keys = {k for k in en if not k.startswith("@")}
    hi_keys = {k for k in hi if not k.startswith("@")}
    for key in sorted(en_keys - hi_keys):
        problems.append(f"{key}: missing from app_hi.arb")
    for key in sorted(hi_keys - en_keys):
        problems.append(f"{key}: present in app_hi.arb but not app_en.arb")
    for key in sorted(en_keys & hi_keys):
        want, got = set(_placeholders(en[key])), set(_placeholders(hi[key]))
        if want != got:
            problems.append(f"{key}: value slots differ -- en {sorted(want)} vs hi {sorted(got)}")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--out",
        type=Path,
        default=REPO_ROOT / "hindi_review.html",
        help="where to write the sheet (default: repo root)",
    )
    args = parser.parse_args()

    en = json.loads((L10N_DIR / "app_en.arb").read_text())
    hi = json.loads((L10N_DIR / "app_hi.arb").read_text())

    problems = check(en, hi)
    if problems:
        print("ARB files disagree -- fix before generating a review sheet:", file=sys.stderr)
        for problem in problems:
            print(f"  {problem}", file=sys.stderr)
        return 1

    args.out.write_text(build(en, hi))
    keys = [k for k in en if not k.startswith("@")]
    same = sum(1 for k in keys if en[k] == hi.get(k))
    print(f"wrote {args.out} -- {len(keys)} strings, {same} still in English")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
