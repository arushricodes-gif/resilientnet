"""
Synthetic Data Generator for Blast Radius Training
--------------------------------------------------
We don't have 10 years of real South India logistics data, so we SIMULATE
disruption cascades using a physics-inspired diffusion model. The GNN then
learns to reproduce this simulated cascade from the disruption pattern alone —
which means at inference time it can predict blast radius for NEW disruption
patterns it hasn't seen.

This is the standard approach for training ML models when only partial real
data exists (also used by weather / epidemic models).

The simulator:
  1. Randomly picks 1-3 nodes as "disruption sources" with severities in [0.5, 1.0]
  2. Builds an adjacency-matrix-based delay diffusion:
        delay_{t+1}[v] = α * disruption[v] + β * Σ_{u ∈ N(v)} A[u,v] * delay_t[u]
  3. Runs the simulation forward T time steps
  4. Final delay vector at time t+k is the LABEL for training

The GNN is given the first few timesteps of features (with risk_score populated
from disruptions) and must predict the final delay per node.
"""

import numpy as np
import torch
import random
from typing import Tuple, List
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from data.graph_builder import SOUTH_INDIA_NODES, SOUTH_INDIA_EDGES

class DisruptionSimulator:
    """Simulates how disruptions propagate through the supply chain graph."""

    def __init__(self, num_nodes: int, edges: List[Tuple], seed: int = None):
        self.num_nodes = num_nodes
        self.edges = edges
        if seed is not None:
            random.seed(seed); np.random.seed(seed)

        # Build weighted adjacency: closer nodes / faster modes propagate delay more
        self.adj = np.zeros((num_nodes, num_nodes))
        for (src, dst, dist_km, mode, hours) in edges:
            # Delay transmission coefficient: shorter/faster edges transmit more
            w = np.exp(-hours / 12.0)          # edges < 12h propagate strongly
            self.adj[src, dst] = max(self.adj[src, dst], w)
            self.adj[dst, src] = max(self.adj[dst, src], w)

        # Row-normalize so each node's received delay is a weighted average
        row_sums = self.adj.sum(axis=1, keepdims=True)
        row_sums[row_sums == 0] = 1.0
        self.adj_norm = self.adj / row_sums

    def simulate(
        self,
        disruption_sources: dict,      # {node_id: severity}
        num_steps: int = 12,
        alpha: float = 0.7,
        beta: float = 0.35,
    ) -> np.ndarray:
        """
        Returns delay trajectory [T, N] where T = num_steps + 1.
        """
        delays = np.zeros(self.num_nodes)
        disruption_vec = np.zeros(self.num_nodes)
        for nid, sev in disruption_sources.items():
            disruption_vec[nid] = sev

        trajectory = [delays.copy()]
        for t in range(num_steps):
            # Neighbor contribution
            neighbor_delay = self.adj_norm @ delays
            # Update: maintain local disruption + diffuse from neighbors, with decay
            new_delays = alpha * disruption_vec + beta * neighbor_delay + 0.85 * delays * 0.5
            new_delays = np.clip(new_delays, 0.0, 1.0)
            delays = new_delays
            trajectory.append(delays.copy())

        return np.array(trajectory)   # [T+1, N]


def generate_training_sample(
    simulator: DisruptionSimulator,
    graph_nodes,
    input_timesteps: int = 6,
    prediction_horizon: int = 12,
) -> Tuple[torch.Tensor, torch.Tensor]:
    """
    Generate one (X, y) pair:
      X: [N, input_timesteps, num_features] — feature sequences
      y: [N] — target delay at t + prediction_horizon
    """
    num_nodes = simulator.num_nodes

    # Pick 1-3 random disruption sources with random severities
    num_sources = random.randint(1, 3)
    source_ids = random.sample(range(num_nodes), num_sources)
    disruption = {sid: random.uniform(0.5, 1.0) for sid in source_ids}

    # Run simulation forward
    total_steps = input_timesteps + prediction_horizon
    trajectory = simulator.simulate(disruption, num_steps=total_steps)

    # Build features for each timestep
    # features per node: [type_oh(3), inventory, avg_delay_so_far, risk, lat_norm, lon_norm, cap]
    X = np.zeros((num_nodes, input_timesteps, 9), dtype=np.float32)
    for t in range(input_timesteps):
        for i, (_, _, _, lat, lon, ntype, cap) in enumerate(graph_nodes):
            type_oh = [0.0] * 3; type_oh[ntype] = 1.0
            # risk_score = current disruption severity (as if NLP detected it)
            risk = disruption.get(i, 0.0) * (1.0 if t >= 1 else 0.3)  # ramp in
            # avg_delay_so_far = mean of trajectory up to t
            avg_delay = trajectory[:t+1, i].mean() if t > 0 else 0.0
            inventory = 0.8 + 0.2 * np.random.rand() - 0.3 * trajectory[t, i]
            inventory = float(np.clip(inventory, 0.0, 1.0))
            feat = type_oh + [
                inventory,
                float(avg_delay),
                float(risk),
                (lat - 8.0) / 10.0,
                (lon - 74.0) / 10.0,
                cap / 2000.0,
            ]
            X[i, t] = feat

    # Label: delay at t = input_timesteps + prediction_horizon
    y = trajectory[input_timesteps + prediction_horizon].astype(np.float32)

    return torch.from_numpy(X), torch.from_numpy(y)


def build_dataset(simulator, graph_nodes, num_samples: int = 1000,
                  input_timesteps: int = 6, prediction_horizon: int = 12):
    """Generate a dataset of (X, y) pairs."""
    dataset = []
    for _ in range(num_samples):
        X, y = generate_training_sample(
            simulator, graph_nodes, input_timesteps, prediction_horizon
        )
        dataset.append((X, y))
    return dataset


if __name__ == "__main__":
    from data.graph_builder import SOUTH_INDIA_NODES, SOUTH_INDIA_EDGES

    sim = DisruptionSimulator(len(SOUTH_INDIA_NODES), SOUTH_INDIA_EDGES, seed=42)

    # Demo: simulate a Kochi Port shutdown and see where it spreads
    print("=== Demo cascade: Kochi Port closure (severity 1.0) ===\n")
    traj = sim.simulate({0: 1.0}, num_steps=12)
    print(f"Trajectory shape: {traj.shape}  (timesteps × nodes)\n")

    print(f"{'Node':30s}  {'t=0':>5s}  {'t=3':>5s}  {'t=6':>5s}  {'t=9':>5s}  {'t=12':>5s}")
    print("-" * 65)
    # Sort nodes by final delay, show top 10
    final_delays = traj[-1]
    ranked = np.argsort(-final_delays)[:10]
    for nid in ranked:
        name = SOUTH_INDIA_NODES[nid][1]
        print(f"{name:30s}  {traj[0,nid]:>5.2f}  {traj[3,nid]:>5.2f}  "
              f"{traj[6,nid]:>5.2f}  {traj[9,nid]:>5.2f}  {traj[12,nid]:>5.2f}")

    print("\n=== Generating a full training sample ===")
    X, y = generate_training_sample(sim, SOUTH_INDIA_NODES)
    print(f"X shape: {tuple(X.shape)}  y shape: {tuple(y.shape)}")
    print(f"y stats: min={y.min():.2f}  max={y.max():.2f}  mean={y.mean():.2f}")
