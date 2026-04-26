"""
Generate 200 synthetic shipments matching the Flutter fake_data.dart schema.

Run once: python generate_shipments.py
Outputs: shipments.json in the same directory.

This is a development utility — not part of the deployed backend.
"""

import json
import random
import math
from pathlib import Path

random.seed(42)

# ------------------------------------------------------------------
# Load hubs
# ------------------------------------------------------------------
HUBS_PATH = Path(__file__).parent / "hubs.json"
with open(HUBS_PATH) as f:
    HUBS = json.load(f)

# ------------------------------------------------------------------
# Cargo types — matches Flutter priority tiers
# ------------------------------------------------------------------
# Tier 1 = critical, Tier 4 = deferrable
CARGO_TYPES = [
    ("medical",     1, 50000,  "tonnes · medical supplies"),
    ("vaccines",    1, 80000,  "pallets · vaccines"),
    ("food",        1, 2000,   "tonnes · food staples"),
    ("fuel",        2, 15000,  "barrels · fuel"),
    ("machinery",   2, 80000,  "containers · auto parts"),
    ("electronics", 3, 25000,  "cartons · electronics"),
    ("textiles",    3, 3000,   "crates · textiles"),
    ("luxury",      4, 100000, "cartons · luxury goods"),
]

STATUSES = ["in_transit", "in_transit", "in_transit", "in_transit", "delivered"]


def haversine_km(lat1, lng1, lat2, lng2):
    """Great-circle distance in km."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lng2 - lng1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlam/2)**2
    return 2 * R * math.asin(math.sqrt(a))


def eta_string(hours):
    """Format ETA as a human-readable string."""
    if hours < 24:
        return f"Today {int(8 + hours) % 24:02d}:00"
    days = int(hours / 24)
    if days == 1:
        return "Tomorrow"
    if days < 7:
        return f"In {days} days"
    return f"In {days // 7} wk {days % 7} d"


# ------------------------------------------------------------------
# Seed shipments — same as Flutter fake_data.dart for demo consistency
# ------------------------------------------------------------------
SEED_SHIPMENTS = [
    {
        "id": "SHP-0042",
        "cargo": "12 cartons · electronics",
        "origin": "Bengaluru DC",
        "destination": "Chennai Port",
        "cargoType": "electronics",
        "priority": 3, "valueInr": 2400000, "riskScore": 0.0,
        "status": "in_transit", "eta": "5:55 PM today",
    },
    {
        "id": "SHP-0118",
        "cargo": "50 tonnes · insulin vials",
        "origin": "Mumbai Port",
        "destination": "Rotterdam",
        "cargoType": "medical",
        "priority": 1, "valueInr": 45000000, "riskScore": 0.0,
        "status": "in_transit", "eta": "12 Feb 18:00",
    },
    {
        "id": "SHP-0203",
        "cargo": "200 containers · auto parts",
        "origin": "Chennai Port",
        "destination": "Frankfurt Air",
        "cargoType": "machinery",
        "priority": 2, "valueInr": 82000000, "riskScore": 0.0,
        "status": "in_transit", "eta": "14 Feb 09:30",
    },
    {
        "id": "SHP-0455",
        "cargo": "30 tonnes · food staples",
        "origin": "JNPT",
        "destination": "Jebel Ali",
        "cargoType": "food",
        "priority": 1, "valueInr": 6500000, "riskScore": 0.0,
        "status": "in_transit", "eta": "9 Feb 22:15",
    },
    {
        "id": "SHP-0789",
        "cargo": "80 crates · textiles",
        "origin": "Ahmedabad Hub",
        "destination": "Singapore",
        "cargoType": "textiles",
        "priority": 3, "valueInr": 1800000, "riskScore": 0.0,
        "status": "in_transit", "eta": "11 Feb 14:20",
    },
    {
        "id": "SHP-0912",
        "cargo": "15 pallets · vaccines",
        "origin": "Delhi Air",
        "destination": "Frankfurt Air",
        "cargoType": "vaccines",
        "priority": 1, "valueInr": 28000000, "riskScore": 0.0,
        "status": "in_transit", "eta": "8 Feb 03:45",
    },
]


def generate_random_shipments(count, existing_ids):
    """Generate `count` additional random shipments."""
    shipments = []
    for i in range(count):
        sid = f"SHP-{1000 + i:04d}"
        while sid in existing_ids:
            sid = f"SHP-{random.randint(1000, 9999):04d}"
        existing_ids.add(sid)

        origin_hub, dest_hub = random.sample(HUBS, 2)
        cargo_name, priority, unit_value, unit_desc = random.choice(CARGO_TYPES)
        units = random.randint(10, 500)

        distance = haversine_km(
            origin_hub["lat"], origin_hub["lng"],
            dest_hub["lat"],   dest_hub["lng"],
        )
        eta_hours = distance / 45.0  # rough 45 km/h avg

        shipments.append({
            "id": sid,
            "cargo": f"{units} {unit_desc}",
            "origin": origin_hub["name"],
            "destination": dest_hub["name"],
            "cargoType": cargo_name,
            "priority": priority,
            "valueInr": units * unit_value,
            "riskScore": 0.0,
            "status": random.choice(STATUSES),
            "eta": eta_string(eta_hours),
        })
    return shipments


def main():
    existing_ids = {s["id"] for s in SEED_SHIPMENTS}
    random_ones = generate_random_shipments(194, existing_ids)
    all_shipments = SEED_SHIPMENTS + random_ones

    out_path = Path(__file__).parent / "shipments.json"
    with open(out_path, "w") as f:
        json.dump(all_shipments, f, indent=2)

    print(f"Generated {len(all_shipments)} shipments → {out_path}")


if __name__ == "__main__":
    main()
