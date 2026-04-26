"""
Graph Construction for Southern India Supply Chain
--------------------------------------------------
Nodes: Major ports, warehouses/logistics hubs, vehicle depots
Edges: NH highways and rail lines connecting them
States covered: Kerala, Karnataka, Telangana, Andhra Pradesh, Tamil Nadu
"""

import torch
from torch_geometric.data import Data
import numpy as np
import json
import os


# Real logistics hubs across South India.
# node_type: 0 = port, 1 = warehouse, 2 = vehicle_depot
SOUTH_INDIA_NODES = [
    # Format: (id, name, state, lat, lon, node_type, capacity)
    # --- PORTS ---
    (0,  "Kochi Port",         "Kerala",        9.9667, 76.2833, 0, 1000),
    (1,  "Chennai Port",       "Tamil Nadu",   13.0827, 80.2707, 0, 1500),
    (2,  "Vizag Port",         "Andhra Pradesh", 17.6868, 83.2185, 0, 1200),
    (3,  "Tuticorin Port",     "Tamil Nadu",    8.7642, 78.1348, 0, 800),
    (4,  "Mangalore Port",     "Karnataka",    12.9141, 74.8560, 0, 900),
    (5,  "Krishnapatnam Port", "Andhra Pradesh", 14.2500, 80.1167, 0, 700),

    # --- WAREHOUSES / LOGISTICS HUBS ---
    (6,  "Bengaluru Warehouse",    "Karnataka",    12.9716, 77.5946, 1, 2000),
    (7,  "Hyderabad Warehouse",    "Telangana",    17.3850, 78.4867, 1, 1800),
    (8,  "Coimbatore Warehouse",   "Tamil Nadu",   11.0168, 76.9558, 1, 1000),
    (9,  "Madurai Warehouse",      "Tamil Nadu",    9.9252, 78.1198, 1,  800),
    (10, "Thiruvananthapuram Hub", "Kerala",        8.5241, 76.9366, 1,  700),
    (11, "Vijayawada Warehouse",   "Andhra Pradesh", 16.5062, 80.6480, 1,  900),
    (12, "Mysuru Warehouse",       "Karnataka",    12.2958, 76.6394, 1,  600),
    (13, "Warangal Warehouse",     "Telangana",    17.9689, 79.5941, 1,  500),
    (14, "Salem Warehouse",        "Tamil Nadu",   11.6643, 78.1460, 1,  700),
    (15, "Kozhikode Warehouse",    "Kerala",       11.2588, 75.7804, 1,  600),

    # --- VEHICLE DEPOTS ---
    (16, "Hosur Depot",      "Tamil Nadu",   12.7409, 77.8253, 2, 400),
    (17, "Tirupati Depot",   "Andhra Pradesh", 13.6288, 79.4192, 2, 350),
    (18, "Nizamabad Depot",  "Telangana",    18.6725, 78.0941, 2, 300),
    (19, "Hubballi Depot",   "Karnataka",    15.3647, 75.1240, 2, 400),
]


# Edges represent transport links. Each edge has a distance (km) and mode
# (road / rail / sea / air-capable). These are approximate routes along real
# NH corridors — good enough for a hackathon-scale model.
# Format: (src, dst, distance_km, mode, base_travel_hours)
# mode: 0 = road, 1 = rail, 2 = sea, 3 = air
SOUTH_INDIA_EDGES = [
    # NH-544 / NH-44 corridor (Kerala — TN — Karnataka)
    (0, 15, 185, 0, 4.5),    # Kochi Port — Kozhikode
    (0, 10, 220, 0, 5.0),    # Kochi — Thiruvananthapuram
    (0, 8,  190, 0, 4.5),    # Kochi — Coimbatore (NH-544 via Palakkad)
    (15, 6, 355, 0, 8.0),    # Kozhikode — Bengaluru
    (8,  6, 360, 0, 7.5),    # Coimbatore — Bengaluru
    (8, 12, 190, 0, 4.5),    # Coimbatore — Mysuru
    (8,  9, 215, 0, 4.5),    # Coimbatore — Madurai
    (8, 14, 160, 0, 3.5),    # Coimbatore — Salem
    (14, 6, 215, 0, 5.0),    # Salem — Bengaluru
    (14, 1, 340, 0, 7.0),    # Salem — Chennai

    # Tamil Nadu coastal
    (1,  14, 340, 0, 7.0),
    (1,  9,  460, 0, 9.5),   # Chennai — Madurai
    (9,  3,  135, 0, 3.0),   # Madurai — Tuticorin
    (3, 10,  280, 0, 6.5),   # Tuticorin — TVM

    # Karnataka corridor
    (4,  6, 355, 0, 8.0),    # Mangalore — Bengaluru
    (4, 19, 320, 0, 7.0),    # Mangalore — Hubballi
    (6, 12, 145, 0, 3.0),    # Bengaluru — Mysuru
    (6, 16,  40, 0, 1.0),    # Bengaluru — Hosur
    (6, 19, 410, 0, 8.5),    # Bengaluru — Hubballi
    (6, 17, 250, 0, 5.5),    # Bengaluru — Tirupati

    # NH-44 backbone (Bengaluru — Hyderabad)
    (6,  7, 570, 0, 11.0),
    (7, 11, 275, 0, 5.5),    # Hyderabad — Vijayawada
    (7, 13, 155, 0, 3.5),    # Hyderabad — Warangal
    (7, 18, 175, 0, 4.0),    # Hyderabad — Nizamabad
    (13, 11, 210, 0, 4.5),

    # AP coast
    (11, 5, 400, 0, 9.0),    # Vijayawada — Krishnapatnam
    (11, 2, 440, 0, 9.5),    # Vijayawada — Vizag
    (5,  1, 325, 0, 7.0),    # Krishnapatnam — Chennai
    (5, 17, 155, 0, 3.5),    # Krishnapatnam — Tirupati
    (17, 1, 140, 0, 3.0),    # Tirupati — Chennai

    # Chennai — Bengaluru (NH-48)
    (1,  6, 345, 0, 7.0),
    (1, 16, 310, 0, 6.5),

    # Rail links (treated as separate edges for multimodal planning)
    (0,  1, 690, 1, 14.0),   # Kochi — Chennai rail
    (6,  7, 570, 1, 10.0),
    (1,  2, 800, 1, 16.0),

    # Sea links (port-to-port cabotage)
    (0,  4, 365, 2, 28.0),   # Kochi — Mangalore by sea
    (1,  2, 800, 2, 45.0),   # Chennai — Vizag by sea
    (1,  3, 620, 2, 35.0),   # Chennai — Tuticorin by sea

    # Air corridors (major hubs only) — used only when road is disrupted
    (6,  7, 500, 3, 1.5),    # BLR — HYD
    (6,  1, 290, 3, 1.0),    # BLR — MAA
    (1,  2, 780, 3, 1.75),   # MAA — VTZ
    (0,  6, 360, 3, 1.25),   # COK — BLR
]


class SupplyChainGraph:
    """Builds and manages the Southern India supply chain graph."""

    def __init__(self):
        self.nodes = SOUTH_INDIA_NODES
        self.edges = SOUTH_INDIA_EDGES
        self.num_nodes = len(self.nodes)
        self.node_id_to_name = {n[0]: n[1] for n in self.nodes}
        self.name_to_node_id = {n[1]: n[0] for n in self.nodes}

    def build_edge_index(self):
        """Return edge_index (2, E) and edge_attr (E, num_features) tensors."""
        edge_src, edge_dst, edge_attrs = [], [], []
        for (src, dst, dist_km, mode, hours) in self.edges:
            # Add both directions so the graph is undirected for GNN aggregation
            edge_src.extend([src, dst])
            edge_dst.extend([dst, src])
            # Edge features: [distance_normalized, mode_onehot(4), base_hours_normalized]
            mode_oh = [0.0] * 4
            mode_oh[mode] = 1.0
            attr = [dist_km / 1000.0] + mode_oh + [hours / 50.0]
            edge_attrs.extend([attr, attr])

        edge_index = torch.tensor([edge_src, edge_dst], dtype=torch.long)
        edge_attr = torch.tensor(edge_attrs, dtype=torch.float)
        return edge_index, edge_attr

    def build_node_features(self, inventory=None, avg_delay=None, risk_score=None):
        """
        Node features per spec:
        [node_type_onehot(3), current_inventory, avg_delay_hours, regional_risk_score,
         lat_norm, lon_norm, capacity_norm]

        If no values are supplied, defaults are used (useful for inference).
        """
        if inventory is None:
            inventory = np.random.uniform(0.3, 1.0, self.num_nodes)
        if avg_delay is None:
            avg_delay = np.random.uniform(0.0, 0.1, self.num_nodes)
        if risk_score is None:
            risk_score = np.zeros(self.num_nodes)

        features = []
        for i, (_, _, _, lat, lon, ntype, cap) in enumerate(self.nodes):
            type_oh = [0.0] * 3
            type_oh[ntype] = 1.0
            feat = type_oh + [
                float(inventory[i]),
                float(avg_delay[i]),
                float(risk_score[i]),
                (lat - 8.0) / 10.0,            # normalize lat roughly to [0, 1]
                (lon - 74.0) / 10.0,           # normalize lon roughly to [0, 1]
                cap / 2000.0,
            ]
            features.append(feat)
        return torch.tensor(features, dtype=torch.float)

    def to_pyg_data(self, inventory=None, avg_delay=None, risk_score=None):
        """Return a PyTorch Geometric Data object ready for model forward-pass."""
        x = self.build_node_features(inventory, avg_delay, risk_score)
        edge_index, edge_attr = self.build_edge_index()
        return Data(x=x, edge_index=edge_index, edge_attr=edge_attr)

    def save(self, path):
        with open(path, "w") as f:
            json.dump({
                "nodes": self.nodes,
                "edges": self.edges,
            }, f, indent=2)


if __name__ == "__main__":
    g = SupplyChainGraph()
    print(f"Built graph with {g.num_nodes} nodes and {len(g.edges)} edges "
          f"(→ {2*len(g.edges)} directed edges after symmetrization)")
    data = g.to_pyg_data()
    print(f"Node feature shape:  {tuple(data.x.shape)}  (num_nodes, num_features)")
    print(f"Edge index shape:    {tuple(data.edge_index.shape)}")
    print(f"Edge attr shape:     {tuple(data.edge_attr.shape)}")
    print(f"\nFeature layout per node: "
          f"[port, warehouse, depot, inventory, avg_delay, risk, lat, lon, capacity]")
    print(f"First 3 nodes:")
    for i in range(3):
        print(f"  {g.node_id_to_name[i]}: {data.x[i].tolist()}")

    os.makedirs("/home/claude/resilientnet/data", exist_ok=True)
    g.save("/home/claude/resilientnet/data/graph.json")
    print("\nSaved graph definition → data/graph.json")
