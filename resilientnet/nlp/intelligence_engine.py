"""
NLP Intelligence Engine
-----------------------
Turns raw news headlines into structured disruption signals the GNN can use.

Pipeline:
  1. News fetching (live via News API if key provided, else mock headlines)
  2. Severity scoring via DistilBERT sentiment model (negative sentiment strength
     is used as a proxy for disruption severity — lightweight & works without
     a custom-trained model)
  3. Entity/location extraction via keyword matching against graph node names
     (can be upgraded to Google Cloud Natural Language API if credentials set)
  4. Mapping to nearest graph node → produces per-node risk_score in [0, 1]

To use a real News API:
    export NEWSAPI_KEY="your_key_here"

To use Google Cloud NL API (optional upgrade):
    export GOOGLE_APPLICATION_CREDENTIALS=/path/to/creds.json
"""
import os
import sys

# 1. FIX THE PATH FIRST
current_path = os.path.abspath(__file__)
while os.path.basename(current_path) != 'Hack2skill':
    current_path = os.path.dirname(current_path)
    if current_path == os.path.dirname(current_path): 
        break
sys.path.append(current_path)

import math
import requests
from typing import List, Dict, Tuple
import numpy as np

from resilientnet.data.graph_builder import SOUTH_INDIA_NODES


NEWSAPI_KEY="9aa590cdd6b9425d9a74dca1229643a5"
# Lazy-load the transformer so the module imports cheaply.
# If the model can't be loaded (offline / no HF access), we fall back to a
# keyword-only scorer. Production deployment should use the real model.
_sentiment_pipeline = None
_use_fallback = False


def _get_sentiment_pipeline():
    global _sentiment_pipeline, _use_fallback
    if _use_fallback:
        return None
    if _sentiment_pipeline is None:
        try:
            from transformers import pipeline
            _sentiment_pipeline = pipeline(
                "sentiment-analysis",
                model="distilbert-base-uncased-finetuned-sst-2-english",
            )
        except Exception as e:
            print(f"[nlp] DistilBERT unavailable ({type(e).__name__}); "
                  f"using keyword-only fallback scorer.")
            _use_fallback = True
            return None
    return _sentiment_pipeline


# Keywords that boost severity scores for logistics-specific disruptions.
# (Sentiment alone isn't enough — "port closed" isn't emotionally negative but
# is logistically catastrophic.)
DISRUPTION_KEYWORDS = {
    # keyword: severity multiplier
    "strike": 0.95,
    "protest": 0.75,
    "blockade": 0.90,
    "closed": 0.85,
    "closes": 0.85,
    "closure": 0.85,
    "shut": 0.85,
    "suspended": 0.80,
    "stranded": 0.75,
    "cyclone": 0.95,
    "heavy rain": 0.70,
    "monsoon": 0.55,
    "flood": 0.90,
    "flooding": 0.90,
    "landslide": 0.90,
    "accident": 0.60,
    "blocked": 0.80,
    "halted": 0.85,
    "congestion": 0.55,
    "delayed": 0.50,
    "delay": 0.50,
    "fire": 0.85,
    "curfew": 0.90,
    "riot": 0.95,
}


# Mock headlines for demo mode (when no NEWSAPI_KEY is set)
MOCK_HEADLINES = [
    "Heavy monsoon rain closes NH-544 near Palakkad, trucks stranded",
    "Port workers strike enters third day at Kochi, cargo movement halted",
    "Cyclone alert issued for Andhra Pradesh coast near Vizag",
    "NH-44 blocked near Hosur after lorry accident, traffic diverted",
    "Bengaluru warehouse operations normal as festival demand peaks",
    "Tamil Nadu government declares holiday, offices closed in Chennai",
    "Flooding reported in Kozhikode, district administration on alert",
    "Hyderabad sees steady logistics activity despite rain warnings",
]


def fetch_news_headlines(api_key: str = None, query: str = None) -> List[str]:
    """
    Fetch recent logistics-relevant headlines.

    If NEWSAPI_KEY is provided, uses newsapi.org. Otherwise returns mock data.
    The query is constrained to the five southern states.
    """
    api_key = api_key or os.getenv("NEWSAPI_KEY")

    if not api_key:
        print("[nlp] No NEWSAPI_KEY set — using mock headlines for demo.")
        return MOCK_HEADLINES

    query = query or (
        '(strike OR "heavy rain" OR protest OR "port closure" OR cyclone '
        'OR flood OR accident OR blockade) AND '
        '(Kerala OR Karnataka OR Telangana OR "Andhra Pradesh" OR "Tamil Nadu")'
    )

    try:
        r = requests.get(
            "https://newsapi.org/v2/everything",
            params={
                "q": query,
                "language": "en",
                "sortBy": "publishedAt",
                "pageSize": 30,
                "apiKey": api_key,
            },
            timeout=10,
        )
        r.raise_for_status()
        articles = r.json().get("articles", [])
        return [a["title"] for a in articles if a.get("title")]
    except Exception as e:
        print(f"[nlp] News API error ({e}); falling back to mock headlines.")
        return MOCK_HEADLINES


def score_severity(headline: str) -> float:
    """
    Return a severity score in [0, 1] for a single headline.
    Combines DistilBERT sentiment with logistics-specific keyword boosting.
    Falls back to keyword-only scoring if DistilBERT is unavailable.
    """
    pipe = _get_sentiment_pipeline()

    # Sentiment component (0 if DistilBERT not available)
    if pipe is not None:
        result = pipe(headline[:512])[0]
        sentiment_component = (
            result["score"] if result["label"] == "NEGATIVE" else 1.0 - result["score"]
        )
    else:
        sentiment_component = 0.0

    # Keyword boost — take the max match (one strong keyword is enough)
    headline_lower = headline.lower()
    keyword_component = 0.0
    for kw, weight in DISRUPTION_KEYWORDS.items():
        if kw in headline_lower:
            keyword_component = max(keyword_component, weight)

    if keyword_component > 0:
        # If we have sentiment, blend 70/30; otherwise keyword-only
        if pipe is not None:
            return float(0.7 * keyword_component + 0.3 * sentiment_component)
        return float(keyword_component)
    # No keyword match — rely on sentiment (capped), or return 0 if no sentiment
    return float(sentiment_component * 0.4) if pipe is not None else 0.0


def map_to_node(headline: str, graph_nodes: List[Tuple]) -> List[int]:
    """
    Keyword-match locations/states in the headline against graph node names.
    Returns a list of matching node IDs.

    graph_nodes is expected to be SOUTH_INDIA_NODES from graph_builder.
    """
    headline_lower = headline.lower()
    matches = []

    for (nid, name, state, _lat, _lon, _ntype, _cap) in graph_nodes:
        # Match on city name (first word usually) or state name
        city = name.split()[0].lower()
        if city in headline_lower:
            matches.append(nid)
        elif state.lower() in headline_lower:
            # Weaker match — add only if nothing more specific found
            if not matches:
                matches.append(nid)

    # Common landmark → node mappings (Hosur → nearest to BLR etc.)
    landmark_map = {
        "hosur":       16,   # Hosur Depot
        "nh44":        6,    # NH-44 backbone runs through BLR
        "nh-44":       6,
        "nh544":       8,    # NH-544 goes through Coimbatore
        "nh-544":      8,
        "palakkad":    8,    # nearest node to Palakkad is Coimbatore
        "tirupati":    17,
        "warangal":    13,
        "vijayawada":  11,
        "mysuru":      12,
        "mysore":      12,
        "salem":       14,
        "madurai":     9,
        "tuticorin":   3,
        "thoothukudi": 3,
        "kozhikode":   15,
        "calicut":     15,
    }
    for kw, nid in landmark_map.items():
        if kw in headline_lower and nid not in matches:
            matches.append(nid)

    return matches


def compute_risk_scores(
    graph_nodes: List[Tuple],
    headlines: List[str] = None,
    decay_km: float = 300.0,
) -> np.ndarray:
    """
    Main entry point: turn a batch of headlines into a per-node risk vector.

    Each matched node gets the headline's severity. Nearby nodes get a
    distance-decayed fraction of that severity (this is the "regional risk
    score" spillover — a disruption at Kochi Port should raise risk at
    Thiruvananthapuram too, even if TVM isn't named in the headline).
    """
    if headlines is None:
        headlines = fetch_news_headlines()

    num_nodes = len(graph_nodes)
    risk = np.zeros(num_nodes)

    # Pre-compute pairwise distances (haversine, rough)
    def hav(lat1, lon1, lat2, lon2):
        R = 6371.0
        p1, p2 = math.radians(lat1), math.radians(lat2)
        dp = math.radians(lat2 - lat1)
        dl = math.radians(lon2 - lon1)
        a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
        return 2 * R * math.asin(math.sqrt(a))

    coords = [(n[3], n[4]) for n in graph_nodes]

    print(f"[nlp] Processing {len(headlines)} headlines...")
    for h in headlines:
        sev = score_severity(h)
        if sev < 0.3:
            continue  # low-severity headline; ignore
        matched = map_to_node(h, graph_nodes)
        if not matched:
            continue
        print(f"  severity={sev:.2f}  nodes={matched}  → {h[:80]}")

        for nid in matched:
            lat, lon = coords[nid]
            for j in range(num_nodes):
                d = hav(lat, lon, *coords[j])
                # Gaussian-ish decay with radius ~decay_km
                decayed = sev * math.exp(-(d ** 2) / (2 * decay_km ** 2))
                risk[j] = max(risk[j], decayed)

    # Clip to [0, 1]
    return np.clip(risk, 0.0, 1.0)


if __name__ == "__main__":


    print("=== NLP Intelligence Engine ===\n")
    headlines = fetch_news_headlines()
    print(f"Fetched {len(headlines)} headlines.\n")

    # Score a few samples
    print("Sample severity scoring:")
    for h in headlines[:4]:
        print(f"  [{score_severity(h):.2f}]  {h}")

    print("\nComputing per-node risk scores...")
    risk = compute_risk_scores(SOUTH_INDIA_NODES, headlines)

    print("\nTop-5 at-risk nodes:")
    ranked = sorted(enumerate(risk), key=lambda x: -x[1])[:5]
    for nid, r in ranked:
        print(f"  {SOUTH_INDIA_NODES[nid][1]:30s}  risk={r:.3f}")
