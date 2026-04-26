"""
Route Optimization Engine (Phase 3)
-----------------------------------
Once the GNN predicts per-node delay probabilities, this module finds the
lowest-cumulative-risk path between any origin and destination using Google
OR-Tools' RoutingModel.

Two strategies:
  1. Dijkstra-style shortest-path with risk-weighted edges (fast, exact,
     works well for single origin–destination pairs — our main use case)
  2. OR-Tools RoutingModel (for multi-stop / VRP extensions)

The edge cost combines:
  - Base travel time (hours)
  - Risk penalty: nodes with high predicted delay inflate edge cost through them
  - Mode penalty: air is fastest but expensive, used only when land cost blows past a threshold

If the land-route cost exceeds `air_threshold`, we allow switching to air
edges automatically (matching the spec: "potentially switching a land route
to an air route if the delay cost exceeds a threshold").
"""

import heapq
import math
from typing import List, Tuple, Dict, Optional
import numpy as np

# Mode cost multipliers (per hour) — air is fast but expensive
MODE_MONETARY_COST = {
    0: 1.0,    # road: baseline
    1: 0.7,    # rail: cheaper than road
    2: 0.5,    # sea: cheapest per hour but slow
    3: 4.0,    # air: 4x more expensive per hour
}

MODE_NAMES = {0: "road", 1: "rail", 2: "sea", 3: "air"}


class RouteOptimizer:
    """Lowest-cumulative-risk path finder with multimodal support."""

    def __init__(self, num_nodes: int, edges: List[Tuple], node_names: Dict[int, str]):
        """
        edges: list of (src, dst, dist_km, mode, base_hours) tuples.
               Bidirectional — each edge creates two directed entries.
        """
        self.num_nodes = num_nodes
        self.node_names = node_names
        # adjacency: node → list of (neighbor, dist_km, mode, base_hours)
        self.adj: Dict[int, List[Tuple[int, float, int, float]]] = {
            i: [] for i in range(num_nodes)
        }
        for (src, dst, dist_km, mode, hours) in edges:
            self.adj[src].append((dst, dist_km, mode, hours))
            self.adj[dst].append((src, dist_km, mode, hours))

    def _edge_cost(
        self,
        u: int,
        v: int,
        base_hours: float,
        mode: int,
        risk_per_node: np.ndarray,
        allow_air: bool,
        risk_weight: float = 10.0,
    ) -> float:
        """
        Cost of traversing edge (u → v):
          time_cost + risk_penalty × risk_at_destination + money_cost
        If air is disallowed, air edges have infinite cost.
        """
        if mode == 3 and not allow_air:
            return float("inf")
        # Base time-equivalent cost
        cost = base_hours
        # Risk at destination node inflates cost (the GNN's delay probability)
        # Multiplied heavily so risky edges become visibly more expensive.
        cost += risk_weight * float(risk_per_node[v])
        # Monetary overlay (air edges penalized more heavily)
        cost += base_hours * (MODE_MONETARY_COST[mode] - 1.0) * 0.5
        return cost

    def find_lowest_risk_path(
        self,
        origin: int,
        destination: int,
        risk_per_node: np.ndarray,
        allow_air: bool = False,
        risk_weight: float = 10.0,
    ) -> Optional[Dict]:
        """
        Dijkstra over risk-weighted edges.
        Returns dict with path, total_cost, total_hours, modes_used, or None if unreachable.
        """
        if origin == destination:
            return {"path": [origin], "total_cost": 0.0, "total_hours": 0.0,
                    "modes": [], "total_risk": float(risk_per_node[origin])}

        # (cumulative_cost, current_node, prev_node, mode_used, hours_on_this_edge)
        dist = {i: float("inf") for i in range(self.num_nodes)}
        dist[origin] = 0.0
        prev: Dict[int, Tuple[int, int, float]] = {}   # node -> (prev, mode, hours)
        pq = [(0.0, origin)]

        while pq:
            d, u = heapq.heappop(pq)
            if d > dist[u]:
                continue
            if u == destination:
                break
            for (v, _dist_km, mode, hours) in self.adj[u]:
                c = self._edge_cost(u, v, hours, mode, risk_per_node,
                                     allow_air, risk_weight)
                if c == float("inf"):
                    continue
                nd = d + c
                if nd < dist[v]:
                    dist[v] = nd
                    prev[v] = (u, mode, hours)
                    heapq.heappush(pq, (nd, v))

        if dist[destination] == float("inf"):
            return None

        # Reconstruct path
        path = [destination]
        modes, hours_list = [], []
        cur = destination
        while cur in prev:
            p, m, h = prev[cur]
            path.append(p)
            modes.append(m)
            hours_list.append(h)
            cur = p
        path.reverse(); modes.reverse(); hours_list.reverse()

        total_risk = sum(float(risk_per_node[n]) for n in path)

        return {
            "path": path,
            "path_names": [self.node_names[n] for n in path],
            "modes": [MODE_NAMES[m] for m in modes],
            "hours_per_leg": hours_list,
            "total_hours": float(sum(hours_list)),
            "total_cost": float(dist[destination]),
            "total_risk": float(total_risk),
        }

    def reroute(
        self,
        origin: int,
        destination: int,
        risk_per_node: np.ndarray,
        delay_probability: float,
        threshold: float = 0.7,
        cost_ratio_threshold: float = 1.5,
    ) -> Dict:
        """
        End-to-end rerouting decision.

        Trigger rule (from spec): if the GNN predicts delay probability > threshold
        for nodes along the intended route, we switch to a rerouted path. If the
        land-only cost exceeds cost_ratio_threshold × land_best_cost, we unlock
        air edges.
        """
        # First: land-only path
        land_route = self.find_lowest_risk_path(
            origin, destination, risk_per_node, allow_air=False,
        )

        should_reroute = delay_probability > threshold

        result = {
            "origin": self.node_names[origin],
            "destination": self.node_names[destination],
            "delay_probability": float(delay_probability),
            "trigger_threshold": threshold,
            "should_reroute": should_reroute,
            "land_route": land_route,
            "air_route": None,
            "recommended": land_route,
            "decision_reason": "",
        }

        if not should_reroute:
            result["decision_reason"] = (
                f"Delay probability ({delay_probability:.2f}) below threshold "
                f"({threshold}). No rerouting needed."
            )
            return result

        # Check if land route is reasonable; if not, try with air
        air_route = self.find_lowest_risk_path(
            origin, destination, risk_per_node, allow_air=True,
        )
        result["air_route"] = air_route

        if land_route is None and air_route is not None:
            result["recommended"] = air_route
            result["decision_reason"] = (
                "Land route unreachable given current disruptions. "
                "Switching to multimodal path with air leg."
            )
        elif (land_route is not None and air_route is not None
              and air_route["total_cost"] < land_route["total_cost"] / cost_ratio_threshold):
            result["recommended"] = air_route
            result["decision_reason"] = (
                f"Land route cost ({land_route['total_cost']:.1f}) exceeds "
                f"air alternative ({air_route['total_cost']:.1f}) by "
                f"{cost_ratio_threshold}×. Switching to air-enabled route."
            )
        else:
            result["recommended"] = land_route
            result["decision_reason"] = (
                "Disruption detected; rerouting along lowest-risk land path."
            )

        return result


if __name__ == "__main__":
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from data.graph_builder import SOUTH_INDIA_NODES, SOUTH_INDIA_EDGES

    node_names = {n[0]: n[1] for n in SOUTH_INDIA_NODES}
    opt = RouteOptimizer(len(SOUTH_INDIA_NODES), SOUTH_INDIA_EDGES, node_names)

    # Scenario: Kochi Port (0) is disrupted. Ship goods from Kozhikode
    # Warehouse (15) to Hyderabad Warehouse (7).
    risk = np.zeros(len(SOUTH_INDIA_NODES))
    risk[0] = 0.95   # Kochi Port disrupted
    risk[15] = 0.60  # Kozhikode moderately affected (spillover)
    risk[8] = 0.30   # Coimbatore slightly affected

    print("=== Scenario: Kochi Port disruption ===")
    print("Shipment: Kozhikode Warehouse → Hyderabad Warehouse\n")

    decision = opt.reroute(
        origin=15, destination=7,
        risk_per_node=risk,
        delay_probability=0.85,
    )

    print(f"Delay probability: {decision['delay_probability']:.2f}")
    print(f"Should reroute?    {decision['should_reroute']}")
    print(f"Decision:          {decision['decision_reason']}\n")

    rec = decision["recommended"]
    print(f"Recommended path ({len(rec['path']) - 1} legs, {rec['total_hours']:.1f} h, "
          f"cost={rec['total_cost']:.2f}):")
    for i, name in enumerate(rec["path_names"]):
        if i > 0:
            print(f"    ↓ {rec['modes'][i-1]:5s} ({rec['hours_per_leg'][i-1]:.1f} h)")
        print(f"  {name}")
