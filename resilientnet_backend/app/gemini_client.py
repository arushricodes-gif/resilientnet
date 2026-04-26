"""
Gemini API client — parses unstructured news into structured disruption events.

This is the "wow" moment of the demo: paste a real news headline, Gemini
reads it, our system extracts a structured disruption event and fires the
cascade predictor.

Why Gemini (not a custom classifier):
    - Zero training data required (works out of the box)
    - Understands natural language well (handles phrasing variations)
    - Fast (~1 second per headline)

Fallback:
    If GEMINI_API_KEY is not set, the parser returns a deterministic mock
    based on simple keyword matching. Lets local dev work without a key.
"""

import os
import json
import re
from typing import Dict

from dotenv import load_dotenv

load_dotenv()  # picks up .env file in the project root

GEMINI_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
GEMINI_AVAILABLE = bool(GEMINI_KEY)

# Lazy import so the service works without the key
_model = None
if GEMINI_AVAILABLE:
    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_KEY)
        _model = genai.GenerativeModel("gemini-1.5-flash")
    except Exception as e:
        print(f"Gemini init failed: {e}")
        GEMINI_AVAILABLE = False


PROMPT_TEMPLATE = """You are analyzing a news headline for supply chain disruption signals.
Return a JSON object with EXACTLY these fields:

- type: one of ["storm", "strike", "accident", "closure", "conflict", "other", "none"]
- location: best-guess city, region, port, or country (or null if not identifiable)
- severity: number from 0.0 (very minor) to 1.0 (catastrophic disruption)
- affected_mode: one of ["sea", "air", "land", "multi", "unknown"]
- confidence: your confidence in this analysis, 0.0 to 1.0

If the headline does not describe a real supply chain disruption, set type="none"
and severity=0.0.

Return ONLY valid JSON, no markdown fences, no explanation.

Headline: "{headline}"
"""


# ============================================================
# Keyword-based fallback (no API key needed)
# ============================================================

def _fallback_parse(headline: str) -> Dict:
    """Simple keyword matching for when Gemini isn't configured."""
    text = headline.lower()

    # Type detection
    type_map = {
        "storm":  ["storm", "cyclone", "hurricane", "typhoon", "monsoon", "flood"],
        "strike": ["strike", "walkout", "protest", "blockade", "union"],
        "accident": ["accident", "crash", "collision", "derail", "fire"],
        "closure": ["closure", "shut", "blocked", "halted", "suspended", "grounded"],
        "conflict": ["attack", "drone", "missile", "houthi", "conflict", "war"],
    }
    detected_type = "other"
    for t, keywords in type_map.items():
        if any(kw in text for kw in keywords):
            detected_type = t
            break

    # Location — extract capitalized words (very rough)
    locations = re.findall(r"\b[A-Z][a-z]+(?:\s[A-Z][a-z]+)*\b", headline)
    common_words = {"The", "A", "An", "Breaking"}
    locations = [l for l in locations if l not in common_words]
    location = locations[0] if locations else None

    # Severity — escalation keywords
    severity = 0.5
    if any(kw in text for kw in ["attack", "catastrophic", "severe", "major"]):
        severity = 0.85
    elif any(kw in text for kw in ["minor", "slight", "brief"]):
        severity = 0.3

    # Mode detection
    if any(kw in text for kw in ["shipping", "port", "vessel", "sea", "strait"]):
        mode = "sea"
    elif any(kw in text for kw in ["flight", "airport", "airspace", "air"]):
        mode = "air"
    elif any(kw in text for kw in ["highway", "road", "truck", "rail"]):
        mode = "land"
    else:
        mode = "unknown"

    return {
        "type": detected_type,
        "location": location,
        "severity": severity,
        "affected_mode": mode,
        "confidence": 0.6,  # lower confidence for fallback
        "raw_response": "(fallback keyword matcher — no Gemini key set)",
    }


# ============================================================
# Main parser
# ============================================================

def parse_news_headline(headline: str) -> Dict:
    """
    Send a news headline to Gemini, receive structured disruption JSON.

    Returns a dict matching the ParsedDisruption pydantic model.
    Always returns valid data — falls back to keyword matching if Gemini fails.
    """
    # No API key? Use fallback.
    if not GEMINI_AVAILABLE or _model is None:
        return _fallback_parse(headline)

    # Try Gemini
    try:
        prompt = PROMPT_TEMPLATE.format(headline=headline.replace('"', "'"))
        response = _model.generate_content(prompt)
        text = response.text.strip()

        # Gemini sometimes wraps JSON in markdown code fences — strip them
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

        parsed = json.loads(text)

        # Make sure all required fields are present; fill defaults if not
        return {
            "type": parsed.get("type", "other"),
            "location": parsed.get("location"),
            "severity": float(parsed.get("severity", 0.5)),
            "affected_mode": parsed.get("affected_mode", "unknown"),
            "confidence": float(parsed.get("confidence", 0.85)),
            "raw_response": text,
        }
    except Exception as e:
        # Any failure — fall back gracefully rather than 500
        print(f"Gemini parse failed, using fallback: {e}")
        result = _fallback_parse(headline)
        result["raw_response"] = f"(Gemini failed: {e} — fallback used)"
        return result
