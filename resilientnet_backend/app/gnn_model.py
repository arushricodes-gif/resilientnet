"""
ST-GCN model definition for the cascade predictor.

This is a copy of the architecture from the teammate's training code.
Kept here so the backend can load the trained weights without needing
the original training folder on the server.

Architecture:
    Input:   [N, T, F] — N nodes, T timesteps, F features
    → LSTM temporal encoder
    → 3 × GCN spatial layers
    → Linear head → per-node delay prediction
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch_geometric.nn import GCNConv


class STGCNRegressor(nn.Module):
    """ST-GCN that predicts raw delay magnitude per node (no sigmoid)."""

    def __init__(
        self,
        num_node_features: int = 10,
        hidden_dim: int = 96,
        num_gcn_layers: int = 3,
        lstm_hidden: int = 48,
        dropout: float = 0.2,
    ):
        super().__init__()
        self.num_node_features = num_node_features
        self.hidden_dim = hidden_dim

        # Temporal encoder
        self.temporal_lstm = nn.LSTM(
            input_size=num_node_features,
            hidden_size=lstm_hidden,
            num_layers=1,
            batch_first=True,
        )

        # Spatial GCN layers
        self.gcn_layers = nn.ModuleList()
        in_dim = lstm_hidden
        for _ in range(num_gcn_layers):
            self.gcn_layers.append(GCNConv(in_dim, hidden_dim))
            in_dim = hidden_dim

        self.dropout = dropout

        # Linear regression head (no sigmoid - matches improved training)
        self.head = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(hidden_dim // 2, 1),
        )

    def forward(self, x_seq, edge_index):
        """
        Args:
            x_seq:      [N, T, F]  node features over time
            edge_index: [2, E]     graph edges in PyG format
        Returns:
            [N]  predicted delay per node
        """
        lstm_out, _ = self.temporal_lstm(x_seq)
        node_embed = lstm_out[:, -1, :]

        h = node_embed
        for i, conv in enumerate(self.gcn_layers):
            h = conv(h, edge_index)
            if i < len(self.gcn_layers) - 1:
                h = F.relu(h)
                h = F.dropout(h, p=self.dropout, training=self.training)

        return self.head(h).squeeze(-1)
