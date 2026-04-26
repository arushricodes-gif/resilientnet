"""
South India logistics graph — matches the GNN training data.

The trained GNN expects these specific 20 nodes and 42 edges, in this
exact order. Do NOT change without retraining.

Node format: (id, name, state, lat, lon, node_type, capacity)
  node_type: 0 = port, 1 = warehouse, 2 = vehicle_depot

Edge format: (src, dst, distance_km, mode, base_travel_hours)
  mode: 0 = road, 1 = rail, 2 = sea, 3 = air
"""

SOUTH_INDIA_NODES = [
    # --- PORTS ---
    (0,  "Kochi Port",         "Kerala",         9.9667, 76.2833, 0, 1000),
    (1,  "Chennai Port",       "Tamil Nadu",    13.0827, 80.2707, 0, 1500),
    (2,  "Vizag Port",         "Andhra Pradesh",17.6868, 83.2185, 0, 1200),
    (3,  "Tuticorin Port",     "Tamil Nadu",     8.7642, 78.1348, 0, 800),
    (4,  "Mangalore Port",     "Karnataka",     12.9141, 74.8560, 0, 900),
    (5,  "Krishnapatnam Port", "Andhra Pradesh",14.2500, 80.1167, 0, 700),

    # --- WAREHOUSES ---
    (6,  "Bengaluru Warehouse",    "Karnataka",    12.9716, 77.5946, 1, 2000),
    (7,  "Hyderabad Warehouse",    "Telangana",    17.3850, 78.4867, 1, 1800),
    (8,  "Coimbatore Warehouse",   "Tamil Nadu",   11.0168, 76.9558, 1, 1000),
    (9,  "Madurai Warehouse",      "Tamil Nadu",    9.9252, 78.1198, 1, 800),
    (10, "Thiruvananthapuram Hub", "Kerala",        8.5241, 76.9366, 1, 700),
    (11, "Vijayawada Warehouse",   "Andhra Pradesh",16.5062, 80.6480, 1, 900),
    (12, "Mysuru Warehouse",       "Karnataka",    12.2958, 76.6394, 1, 600),
    (13, "Warangal Warehouse",     "Telangana",    17.9689, 79.5941, 1, 500),
    (14, "Salem Warehouse",        "Tamil Nadu",   11.6643, 78.1460, 1, 700),
    (15, "Kozhikode Warehouse",    "Kerala",       11.2588, 75.7804, 1, 600),

    # --- VEHICLE DEPOTS ---
    (16, "Hosur Depot",      "Tamil Nadu",     12.7409, 77.8253, 2, 400),
    (17, "Tirupati Depot",   "Andhra Pradesh", 13.6288, 79.4192, 2, 350),
    (18, "Nizamabad Depot",  "Telangana",      18.6725, 78.0941, 2, 300),
    (19, "Hubballi Depot",   "Karnataka",      15.3647, 75.1240, 2, 400),
]

SOUTH_INDIA_EDGES = [
    # Kerala-TN-Karnataka corridor
    (0, 15, 185, 0, 4.5), (0, 10, 220, 0, 5.0), (0, 8, 190, 0, 4.5),
    (15, 6, 355, 0, 8.0), (8, 6, 360, 0, 7.5), (8, 12, 190, 0, 4.5),
    (8, 9, 215, 0, 4.5), (8, 14, 160, 0, 3.5), (14, 6, 215, 0, 5.0),
    (14, 1, 340, 0, 7.0),
    # TN coastal
    (1, 14, 340, 0, 7.0), (1, 9, 460, 0, 9.5), (9, 3, 135, 0, 3.0),
    (3, 10, 280, 0, 6.5),
    # Karnataka
    (4, 6, 355, 0, 8.0), (4, 19, 320, 0, 7.0), (6, 12, 145, 0, 3.0),
    (6, 16, 40, 0, 1.0), (6, 19, 410, 0, 8.5), (6, 17, 250, 0, 5.5),
    # NH-44 backbone
    (6, 7, 570, 0, 11.0), (7, 11, 275, 0, 5.5), (7, 13, 155, 0, 3.5),
    (7, 18, 175, 0, 4.0), (13, 11, 210, 0, 4.5),
    # AP coast
    (11, 5, 400, 0, 9.0), (11, 2, 440, 0, 9.5), (5, 1, 325, 0, 7.0),
    (5, 17, 155, 0, 3.5), (17, 1, 140, 0, 3.0),
    # Chennai-Bengaluru
    (1, 6, 345, 0, 7.0), (1, 16, 310, 0, 6.5),
    # Rail
    (0, 1, 690, 1, 14.0), (6, 7, 570, 1, 10.0), (1, 2, 800, 1, 16.0),
    # Sea
    (0, 4, 365, 2, 28.0), (1, 2, 800, 2, 45.0), (1, 3, 620, 2, 35.0),
    # Air
    (6, 7, 500, 3, 1.5), (6, 1, 290, 3, 1.0), (1, 2, 780, 3, 1.75),
    (0, 6, 360, 3, 1.25),
]

# Quick lookups
NODE_BY_ID = {n[0]: n for n in SOUTH_INDIA_NODES}
NODE_BY_NAME = {n[1]: n[0] for n in SOUTH_INDIA_NODES}
NUM_NODES = len(SOUTH_INDIA_NODES)
