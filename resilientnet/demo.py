"""
ResilientNet End-to-End Demo
----------------------------
Demonstrates the full pipeline:

  1. NLP ingests news headlines → computes per-node regional risk scores
  2. ST-GCN takes those risk scores + node features → predicts delay at t+12h
  3. For every at-risk shipment (predicted_delay > 0.7), OR-Tools finds
     the lowest-cumulative-risk reroute (swapping to air if needed)

Run:
    python demo.py                           # uses mock headlines
    NEWSAPI_KEY=xxx python demo.py           # uses live news
    python demo.py --scenario kochi_closure  # forces a specific scenario
"""

import os
import sys
import argparse
import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from data.graph_builder import SupplyChainGraph, SOUTH_INDIA_NODES, SOUTH_INDIA_EDGES
from nlp.intelligence_engine import fetch_news_headlines, compute_risk_scores
from models.stgcn import STGCNRegressor
from optimization.rerouter import RouteOptimizer

NEWSAPI_KEY="9aa590cdd6b9425d9a74dca1229643a5"

# Predefined scenarios that override the News API for reproducible demos
SCENARIOS = {
    "kochi_closure": [
        "Port workers strike enters third day at Kochi, cargo movement halted",
        "Heavy monsoon rain closes NH-544 near Palakkad, trucks stranded",
    ],
    "cyclone_ap": [
        "Cyclone alert issued for Andhra Pradesh coast near Vizag",
        "Flooding reported near Krishnapatnam, vessels diverted",
    ],
    "nh44_block": [
        "NH-44 blocked near Hosur after lorry accident, traffic diverted",
        "Bengaluru warehouse reports stranded shipments from Tamil Nadu",
    ],
}

# Shipments to check. Each is (origin_node, dest_node, description).
DEFAULT_SHIPMENTS = [
    (15, 7,  "Textiles: Kozhikode → Hyderabad"),
    (0,  6,  "Spices:   Kochi Port → Bengaluru"),
    (2,  11, "Steel:    Vizag Port → Vijayawada"),
    (3,  1,  "Cotton:   Tuticorin → Chennai Port"),
    (4,  6,  "Cashews:  Mangalore Port → Bengaluru"),
    (0,  7,  "Cardamom: Kochi Port → Hyderabad"),
]


def build_input_features(graph, risk_scores, input_timesteps=6):
    """Assemble the [N, T, F] input tensor for the GNN from current risk scores."""
    num_nodes = graph.num_nodes
    X = np.zeros((num_nodes, input_timesteps, 9), dtype=np.float32)
    for t in range(input_timesteps):
        for i, (_, _, _, lat, lon, ntype, cap) in enumerate(SOUTH_INDIA_NODES):
            type_oh = [0.0] * 3; type_oh[ntype] = 1.0
            risk = float(risk_scores[i]) * (0.3 + 0.7 * (t / max(input_timesteps - 1, 1)))
            feat = type_oh + [
                0.8,                          # assume normal inventory
                float(risk_scores[i]) * 0.3,  # mild avg_delay proxy
                risk,
                (lat - 8.0) / 10.0,
                (lon - 74.0) / 10.0,
                cap / 2000.0,
            ]
            X[i, t] = feat
    return torch.from_numpy(X)


def load_model(checkpoint_path, device="cpu"):
    """Load the trained ST-GCN checkpoint."""
    ckpt = torch.load(checkpoint_path, map_location=device, weights_only=False)
    cfg = ckpt["config"]
    model = STGCNRegressor(
        num_node_features=cfg["num_node_features"],
        hidden_dim=cfg["hidden_dim"],
        num_gcn_layers=cfg["num_gcn_layers"],
    ).to(device)
    model.load_state_dict(ckpt["model_state_dict"])
    model.eval()
    return model, cfg


def shipment_delay_probability(predicted_delays, origin, destination, graph):
    """
    Risk a shipment actually faces = max predicted delay along its likely path.
    Quick approximation: use a shortest-by-hops BFS to find a candidate corridor
    through the graph, then take the max predicted delay across those nodes.
    """
    from collections import deque
    adj = {i: set() for i in range(graph.num_nodes)}
    for (u, v, *_) in graph.edges:
        adj[u].add(v); adj[v].add(u)

    parent = {origin: None}
    q = deque([origin])
    while q:
        u = q.popleft()
        if u == destination:
            break
        for v in adj[u]:
            if v not in parent:
                parent[v] = u
                q.append(v)

    if destination not in parent:
        return float(predicted_delays[origin])

    path = []
    cur = destination
    while cur is not None:
        path.append(cur)
        cur = parent[cur]

    return float(max(predicted_delays[n] for n in path))


def run_demo(scenario=None, checkpoint="/home/claude/resilientnet/models/stgcn_trained.pt",
             reroute_threshold=0.5):
    print("=" * 70)
    print("  RESILIENTNET — End-to-End Disruption Response Demo")
    print("=" * 70)

    # ---- 1. Build graph ----
    graph = SupplyChainGraph()
    node_names = {n[0]: n[1] for n in SOUTH_INDIA_NODES}
    print(f"\n[1/5] Graph built: {graph.num_nodes} nodes, {len(graph.edges)} edges "
          f"across 5 southern states")

    # ---- 2. NLP → risk scores ----
    if scenario and scenario in SCENARIOS:
        print(f"\n[2/5] Using scenario '{scenario}' (overriding live news)")
        headlines = SCENARIOS[scenario]
    else:
        print("\n[2/5] Fetching live news headlines...")
        headlines = fetch_news_headlines()

    print(f"      {len(headlines)} headlines loaded. Computing per-node risk...")
    risk_scores = compute_risk_scores(SOUTH_INDIA_NODES, headlines)

    top_risk = sorted(enumerate(risk_scores), key=lambda x: -x[1])[:5]
    print(f"\n      Top 5 at-risk nodes (NLP layer):")
    for nid, r in top_risk:
        bar = "█" * int(r * 30)
        print(f"        {node_names[nid]:30s}  {r:.2f}  {bar}")

    # ---- 3. Load GNN & predict ----
    if not os.path.exists(checkpoint):
        print(f"\n[3/5] ⚠  No trained checkpoint at {checkpoint}. "
              f"Run train.py first. Using untrained model for demo.")
        model = STGCNRegressor(num_node_features=9, hidden_dim=64, num_gcn_layers=3)
        model.eval()
    else:
        print(f"\n[3/5] Loading trained ST-GCN from {checkpoint}")
        model, cfg = load_model(checkpoint)

    print("      Running forward pass (ST-GCN)...")
    X = build_input_features(graph, risk_scores)
    edge_index, _ = graph.build_edge_index()
    with torch.no_grad():
        predicted_delays = model(X, edge_index).numpy()

    # Clip and normalize so the demo output is readable
    predicted_delays = np.clip(predicted_delays, 0.0, 1.0)

    top_pred = sorted(enumerate(predicted_delays), key=lambda x: -x[1])[:5]
    print(f"\n      Top 5 predicted-delay nodes at t+12h (GNN 'blast radius'):")
    for nid, p in top_pred:
        bar = "█" * int(p * 30)
        print(f"        {node_names[nid]:30s}  {p:.2f}  {bar}")

    # ---- 4. Rerouting decisions ----
    print(f"\n[4/5] Evaluating {len(DEFAULT_SHIPMENTS)} shipments against blast-radius forecast")
    print(f"      (rerouting trigger: predicted corridor delay > {reroute_threshold})\n")

    optimizer = RouteOptimizer(graph.num_nodes, SOUTH_INDIA_EDGES, node_names)
    reroute_count = 0
    for origin, dest, desc in DEFAULT_SHIPMENTS:
        corridor_risk = shipment_delay_probability(predicted_delays, origin, dest, graph)
        decision = optimizer.reroute(
            origin=origin, destination=dest,
            risk_per_node=predicted_delays,
            delay_probability=corridor_risk,
            threshold=reroute_threshold,
        )

        status = "🔀 REROUTE" if decision["should_reroute"] else "✅ on-track"
        print(f"   {status}  {desc}")
        print(f"              corridor risk = {corridor_risk:.2f}")

        if decision["should_reroute"]:
            reroute_count += 1
            rec = decision["recommended"]
            if rec is None:
                print(f"              ⚠  No viable path found.")
            else:
                legs = " → ".join(rec["path_names"])
                modes = "/".join(sorted(set(rec["modes"])))
                print(f"              new path: {legs}")
                print(f"              {rec['total_hours']:.1f} h via {modes} "
                      f"(cost={rec['total_cost']:.1f})")
        print()

    # ---- 5. Summary ----
    print("[5/5] Summary")
    print(f"      Shipments evaluated:   {len(DEFAULT_SHIPMENTS)}")
    print(f"      Shipments rerouted:    {reroute_count}")
    print(f"      Avg predicted delay:   {predicted_delays.mean():.3f}")
    print(f"      Max predicted delay:   {predicted_delays.max():.3f}")
    print(f"      Mean NLP risk:         {risk_scores.mean():.3f}")
    print("\n" + "=" * 70)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario", choices=list(SCENARIOS.keys()), default=None,
                    help="Use a predefined scenario instead of live news")
    ap.add_argument("--checkpoint", default="/home/claude/resilientnet/models/stgcn_trained.pt",
                    help="Path to trained ST-GCN checkpoint")
    ap.add_argument("--threshold", type=float, default=0.5,
                    help="Rerouting trigger: predicted delay above this value")
    args = ap.parse_args()

    run_demo(scenario=args.scenario, checkpoint=args.checkpoint,
             reroute_threshold=args.threshold)
