"""
Data loader — reads hubs.json and shipments.json at startup.

In production, this would be replaced with a Firestore read. For the hackathon
we load synthetic data at startup and keep it in memory.
"""

import json
from pathlib import Path
from typing import Dict, List

# Path to the data directory (sibling of app/)
DATA_DIR = Path(__file__).parent.parent / "data"


def _load_json(filename: str) -> list:
    path = DATA_DIR / filename
    if not path.exists():
        raise FileNotFoundError(
            f"Missing data file: {path}\n"
            f"Run 'python data/generate_shipments.py' to create it."
        )
    with open(path) as f:
        return json.load(f)


def load_hubs() -> List[Dict]:
    """Load the 15 hubs from hubs.json."""
    return _load_json("hubs.json")


def load_shipments() -> List[Dict]:
    """Load 200 shipments from shipments.json."""
    return _load_json("shipments.json")


# ============================================================
# INDEXES — built once at startup for O(1) lookups
# ============================================================

HUBS_LIST: List[Dict] = load_hubs()
SHIPMENTS_LIST: List[Dict] = load_shipments()

# Index by ID for fast lookup
HUBS_BY_ID: Dict[str, Dict] = {h["id"]: h for h in HUBS_LIST}
SHIPMENTS_BY_ID: Dict[str, Dict] = {s["id"]: s for s in SHIPMENTS_LIST}

# Index hubs by name — shipments reference hubs by name in the JSON
# (e.g. "Bengaluru DC" → the hub dict). We need this to convert back to ID.
HUBS_BY_NAME: Dict[str, Dict] = {h["name"]: h for h in HUBS_LIST}


def hub_id_from_name(name: str) -> str:
    """Resolve a hub name (e.g. 'Mumbai Port') to its ID (e.g. 'HUB-00')."""
    hub = HUBS_BY_NAME.get(name)
    if hub is None:
        # Name not found — return a sentinel so the algorithm can skip gracefully
        return "HUB-UNKNOWN"
    return hub["id"]
