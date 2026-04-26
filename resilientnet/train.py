"""
Train the ST-GCN 'Blast Radius' Predictor
-----------------------------------------
Phase 2 of the implementation plan:
  - Simulate disruptions (random sources, random severities)
  - Train the GNN to predict the delay at every node at t+12h
  - Loss: MSE between predicted and simulated delay
"""

import os
import sys
import time
import torch
import torch.nn as nn
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from data.graph_builder import SupplyChainGraph, SOUTH_INDIA_NODES, SOUTH_INDIA_EDGES
from data.synthetic_data import DisruptionSimulator, build_dataset
from models.stgcn import STGCNRegressor


def train(
    num_train_samples: int = 800,
    num_val_samples: int = 200,
    epochs: int = 40,
    batch_size: int = 16,
    lr: float = 1e-3,
    input_timesteps: int = 6,
    prediction_horizon: int = 12,
    device: str = "cpu",
    save_path: str = "/home/claude/resilientnet/models/stgcn_trained.pt",
    seed: int = 42,
):
    torch.manual_seed(seed); np.random.seed(seed)

    # --- Build graph & static edge_index ---
    graph = SupplyChainGraph()
    edge_index, _ = graph.build_edge_index()
    edge_index = edge_index.to(device)
    num_nodes = graph.num_nodes
    print(f"Graph: {num_nodes} nodes, {edge_index.shape[1]} directed edges")

    # --- Build synthetic datasets ---
    print(f"Generating {num_train_samples} training samples + {num_val_samples} val samples...")
    t0 = time.time()
    sim = DisruptionSimulator(num_nodes, SOUTH_INDIA_EDGES, seed=seed)
    train_set = build_dataset(
        sim, SOUTH_INDIA_NODES, num_train_samples,
        input_timesteps, prediction_horizon,
    )
    val_set = build_dataset(
        sim, SOUTH_INDIA_NODES, num_val_samples,
        input_timesteps, prediction_horizon,
    )
    print(f"Data generation: {time.time() - t0:.1f}s")

    # --- Model & optimizer ---
    model = STGCNRegressor(num_node_features=9, hidden_dim=64, num_gcn_layers=3).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr, weight_decay=1e-5)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
    criterion = nn.MSELoss()

    n_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Model: ST-GCN Regressor, {n_params:,} parameters")

    # --- Training loop ---
    history = {"train_loss": [], "val_loss": [], "val_mae": []}
    best_val = float("inf")

    for epoch in range(epochs):
        # ---- train ----
        model.train()
        # Shuffle
        indices = np.random.permutation(len(train_set))
        epoch_losses = []
        for start in range(0, len(train_set), batch_size):
            batch_ids = indices[start:start + batch_size]
            optimizer.zero_grad()
            batch_loss = 0.0
            for idx in batch_ids:
                X, y = train_set[idx]
                X, y = X.to(device), y.to(device)
                pred = model(X, edge_index)
                loss = criterion(pred, y)
                batch_loss = batch_loss + loss
            batch_loss = batch_loss / len(batch_ids)
            batch_loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            epoch_losses.append(batch_loss.item())

        # ---- validate ----
        model.eval()
        val_losses, val_maes = [], []
        with torch.no_grad():
            for X, y in val_set:
                X, y = X.to(device), y.to(device)
                pred = model(X, edge_index)
                val_losses.append(criterion(pred, y).item())
                val_maes.append(torch.abs(pred - y).mean().item())

        tr_loss = float(np.mean(epoch_losses))
        val_loss = float(np.mean(val_losses))
        val_mae = float(np.mean(val_maes))
        history["train_loss"].append(tr_loss)
        history["val_loss"].append(val_loss)
        history["val_mae"].append(val_mae)

        scheduler.step()

        if val_loss < best_val:
            best_val = val_loss
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            torch.save({
                "model_state_dict": model.state_dict(),
                "config": {
                    "num_node_features": 9,
                    "hidden_dim": 64,
                    "num_gcn_layers": 3,
                    "input_timesteps": input_timesteps,
                    "prediction_horizon": prediction_horizon,
                },
                "val_loss": val_loss,
                "val_mae": val_mae,
            }, save_path)
            tag = " ★ saved"
        else:
            tag = ""

        print(f"Epoch {epoch+1:3d}/{epochs}  "
              f"train_mse={tr_loss:.4f}  val_mse={val_loss:.4f}  val_mae={val_mae:.4f}"
              f"  lr={optimizer.param_groups[0]['lr']:.2e}{tag}")

    # --- Final qualitative check ---
    print(f"\nBest val MSE: {best_val:.4f}")
    print(f"Model saved to: {save_path}")

    print("\n=== Sanity check: Kochi Port disruption prediction ===")
    model.eval()
    # Build an input where Kochi Port (node 0) has a severity=1.0 disruption
    X_test = torch.zeros(num_nodes, input_timesteps, 9)
    for t in range(input_timesteps):
        for i, (_, _, _, lat, lon, ntype, cap) in enumerate(SOUTH_INDIA_NODES):
            type_oh = [0.0] * 3; type_oh[ntype] = 1.0
            risk = 1.0 if i == 0 else 0.0
            feat = type_oh + [
                0.8,  # inventory
                0.0,  # avg_delay
                risk,
                (lat - 8.0) / 10.0,
                (lon - 74.0) / 10.0,
                cap / 2000.0,
            ]
            X_test[i, t] = torch.tensor(feat)

    with torch.no_grad():
        pred = model(X_test.to(device), edge_index).cpu().numpy()

    # Also run the simulator for comparison
    true_delay = sim.simulate({0: 1.0}, num_steps=input_timesteps + prediction_horizon)[-1]

    print(f"\n{'Node':30s}  {'predicted':>10s}  {'simulated':>10s}  {'error':>8s}")
    print("-" * 65)
    ranked = np.argsort(-pred)[:10]
    for nid in ranked:
        name = SOUTH_INDIA_NODES[nid][1]
        print(f"{name:30s}  {pred[nid]:>10.3f}  {true_delay[nid]:>10.3f}  "
              f"{abs(pred[nid] - true_delay[nid]):>8.3f}")

    return model, history


if __name__ == "__main__":
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Training on: {device}\n")
    train(device=device)
