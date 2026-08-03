"""Templated match-explanation generator.

Deterministic priority-order rules over score_components and the surrounding
context. Returns a dict with `fit`, `caveat`, `generator`, `generator_version`
fields for storage on matches.explanation.

When the LLM provider decision (BRD §14 #1) is resolved, a MatchExplainer
Protocol will wrap both templated and LLM impls behind a single interface
and the score worker call site stays unchanged.

If the templates change semantically, bump GENERATOR_VERSION.
"""

from __future__ import annotations

from decimal import Decimal

GENERATOR = "templated"
GENERATOR_VERSION = "1"

# Two-language copy table, keyed by template line. One code path decides
# *which* line applies (priority-order logic below); this table only supplies
# the words. `{}` slots are filled via str.format with job titles/employer
# names/city names verbatim — never transliterated.
_FIT_TEMPLATES = {
    "en": {
        "low_confidence": "Lower-confidence match - surfaced for breadth.",
        "strong": "Strong match: {job_title} in {overlap_loc} aligns with your experience level.",
        "good_loc_exp": "Good location and seniority fit for {job_title} in {overlap_loc}.",
        "remote": "Remote-friendly match for {job_title} at {employer_name}.",
        "possible": "Possible match for {job_title} based on your skill profile.",
    },
    "hi": {
        "low_confidence": "कम-विश्वसनीय मैच - व्यापक जानकारी हेतु दिखाया गया है।",
        "strong": "बेहतरीन मैच: {overlap_loc} में {job_title} आपके अनुभव स्तर से मेल खाता है।",
        "good_loc_exp": "{overlap_loc} में {job_title} के लिए स्थान और अनुभव स्तर उपयुक्त है।",
        "remote": "{employer_name} में {job_title} के लिए रिमोट-अनुकूल मैच।",
        "possible": "आपकी कौशल प्रोफ़ाइल के आधार पर {job_title} के लिए संभावित मैच।",
    },
}

_CAVEAT_TEMPLATES = {
    "en": {
        "exp": (
            "Experience band: this role asks for " "{job_min_exp_years}-{job_max_exp_years} years."
        ),
        "ctc": "Compensation may be below your expectation.",
        "location": "Location mismatch - neither side lists overlap or remote.",
        "none": "",
    },
    "hi": {
        "exp": (
            "अनुभव सीमा: इस भूमिका के लिए "
            "{job_min_exp_years}-{job_max_exp_years} वर्षों का अनुभव अपेक्षित है।"
        ),
        "ctc": "वेतन आपकी अपेक्षा से कम हो सकता है।",
        "location": "स्थान बेमेल - न तो कोई सामान्य स्थान है और न ही रिमोट विकल्प।",
        "none": "",
    },
}


def templated_explanation(
    *,
    components: dict[str, float],
    vector: float,
    structured: float,
    total: float,
    threshold: float,
    job_title: str,
    job_locations: list[str],
    job_min_exp_years: int,
    job_max_exp_years: int,
    job_ctc_max: Decimal | None,
    employer_name: str,
    applicant_expected_ctc: Decimal | None,
    applicant_locations: list[str],
    language: str = "en",
) -> dict[str, str]:
    loc = components.get("location", 0.5)
    exp = components.get("exp", 0.5)
    ctc = components.get("ctc", 0.5)

    overlap_loc = _location_for_message(job_locations, applicant_locations)
    remote = "remote" in {x.strip().lower() for x in (job_locations + applicant_locations)}

    fit_copy = _FIT_TEMPLATES.get(language, _FIT_TEMPLATES["en"])
    caveat_copy = _CAVEAT_TEMPLATES.get(language, _CAVEAT_TEMPLATES["en"])

    # --- fit string (priority order) ---
    if total < threshold:
        fit_key = "low_confidence"
    elif loc >= 0.9 and exp >= 0.9 and ctc >= 0.9:
        fit_key = "strong"
    elif loc >= 0.9 and exp >= 0.9:
        fit_key = "good_loc_exp"
    elif remote:
        fit_key = "remote"
    else:
        fit_key = "possible"
    fit = fit_copy[fit_key].format(
        job_title=job_title, overlap_loc=overlap_loc, employer_name=employer_name
    )

    # --- caveat string (first weakness wins) ---
    if exp < 0.6:
        caveat_key = "exp"
    elif (
        ctc < 0.6
        and applicant_expected_ctc is not None
        and job_ctc_max is not None
        and applicant_expected_ctc > job_ctc_max
    ):
        caveat_key = "ctc"
    elif loc == 0.0:
        caveat_key = "location"
    else:
        caveat_key = "none"
    caveat = caveat_copy[caveat_key].format(
        job_min_exp_years=job_min_exp_years, job_max_exp_years=job_max_exp_years
    )

    return {
        "fit": fit,
        "caveat": caveat,
        "generator": GENERATOR,
        "generator_version": GENERATOR_VERSION,
    }


def _location_for_message(job_locs: list[str], applicant_locs: list[str]) -> str:
    """Return the first overlapping location for display, or the first job
    location. Case-insensitive match, but preserves casing from the job side."""
    if not job_locs:
        return "your preferred location"
    a_lower = {x.strip().lower() for x in applicant_locs}
    for loc in job_locs:
        if loc.strip().lower() in a_lower:
            return loc
    return job_locs[0]
