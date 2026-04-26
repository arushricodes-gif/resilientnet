"""
Spatio-Temporal Graph Convolutional Network (ST-GCN)
----------------------------------------------------
The core model that learns the 'blast radius' of a supply chain disruption.

Architecture:
   Input:   [T, N, F]  — T time steps, N nodes, F features per node
   Temporal LSTM: processes each node's feature sequence through time
   Spatial GCN:   aggregates info from neighbors using edge_index
   Output:  [N, 1]    — predicted delay probability (0-1) at target time t+k
                       for every node

The GNN is trained to predict: given a disruption at node X (modeled by
spiking its risk_score feature), what will the delay be at every other node
12 hours later? This is exactly the 'blast radius' formulation from the spec.
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch_geometric.nn import GCNConv


class STGCN(nn.Module):
    """Spatio-Temporal GCN with LSTM temporal encoder + stacked GCN layers."""

    def __init__(
        self,
        num_node_features: int = 9,
        hidden_dim: int = 64,
        num_gcn_layers: int = 3,
        lstm_hidden: int = 32,
        dropout: float = 0.2,
    ):
        super().__init__()
        self.num_node_features = num_node_features
        self.hidden_dim = hidden_dim

        # --- Temporal encoder ---
        # Each node has a sequence of feature vectors over T time steps.
        # We use an LSTM to compress [T, F] → [lstm_hidden] per node.
        self.temporal_lstm = nn.LSTM(
            input_size=num_node_features,
            hidden_size=lstm_hidden,
            num_layers=1,
            batch_first=True,
        )

        # --- Spatial encoder (stack of GCNConv layers) ---
        self.gcn_layers = nn.ModuleList()
        in_dim = lstm_hidden
        for _ in range(num_gcn_layers):
            self.gcn_layers.append(GCNConv(in_dim, hidden_dim))
            in_dim = hidden_dim

        self.dropout = dropout

        # --- Prediction head ---
        # Predicts delay probability ∈ [0, 1] for every node.
        self.head = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(hidden_dim // 2, 1),
            nn.Sigmoid(),
        )

    def forward(self, x_seq, edge_index):
        """
        Args:
            x_seq:      [N, T, F]  — for each of N nodes, T time steps of F features
            edge_index: [2, E]     — PyG-style edge indices

        Returns:
            delay_prob: [N]        — predicted delay probability per node at t+k
        """
        # 1) Temporal encoding: LSTM treats each node's sequence independently
        # LSTM expects [batch, seq, feature]; our 'batch' is N nodes.
        lstm_out, (h_n, _) = self.temporal_lstm(x_seq)     # lstm_out: [N, T, lstm_hidden]
        node_embed = lstm_out[:, -1, :]                    # take last timestep: [N, lstm_hidden]

        # 2) Spatial encoding: propagate through the graph
        h = node_embed
        for i, conv in enumerate(self.gcn_layers):
            h = conv(h, edge_index)
            if i < len(self.gcn_layers) - 1:
                h = F.relu(h)
                h = F.dropout(h, p=self.dropout, training=self.training)

        # 3) Per-node delay prediction
        out = self.head(h).squeeze(-1)    # [N]
        return out


class STGCNRegressor(STGCN):
    """Variant that predicts raw delay magnitude (hours) instead of probability.
    Useful for MSE training as specified in Phase 2 of the project brief."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Replace the sigmoid head with a linear one (no activation)
        self.head = nn.Sequential(
            nn.Linear(self.hidden_dim, self.hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(self.hidden_dim // 2, 1),
        )

    def forward(self, x_seq, edge_index):
        lstm_out, _ = self.temporal_lstm(x_seq)
        node_embed = lstm_out[:, -1, :]
        h = node_embed
        for i, conv in enumerate(self.gcn_layers):
            h = conv(h, edge_index)
            if i < len(self.gcn_layers) - 1:
                h = F.relu(h)
                h = F.dropout(h, p=self.dropout, training=self.training)
        return self.head(h).squeeze(-1)


if __name__ == "__main__":
    # Sanity check
    N, T, F_ = 20, 6, 9
    model = STGCN(num_node_features=F_)
    x_seq = torch.randn(N, T, F_)
    # Fake edge_index (ring graph)
    edge_src = list(range(N)); edge_dst = [(i + 1) % N for i in range(N)]
    edge_index = torch.tensor([edge_src + edge_dst, edge_dst + edge_src], dtype=torch.long)
    out = model(x_seq, edge_index)
    print(f"ST-GCN forward pass OK. Output shape: {tuple(out.shape)} (expect ({N},))")
    print(f"Sample predictions: {out[:5].tolist()}")
    n_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"Trainable parameters: {n_params:,}")
