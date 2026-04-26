"""
Pydantic models — the data contract between Flutter and this backend.

Every request body and response is typed. Pydantic validates incoming JSON
and catches shape mismatches before they hit our algorithm code.
"""

from typing import List, Optional
from pydantic import BaseModel, Field


# ============================================================
# CASCADE PREDICTION
# ============================================================

class DisruptionEvent(BaseModel):
    """Input for /predict_cascade — a disruption at a specific hub."""
    hub_id: str = Field(..., description="Hub ID affected, e.g. 'HUB-00'")
    severity: float = Field(..., ge=0.0, le=1.0, description="0.0 to 1.0")
    event_type: str = Field(default="unknown",
                            description="cyclone / strike / closure / accident / other")
    max_depth: int = Field(default=3, ge=1, le=5,
                           description="How many hops to propagate")


class AffectedShipment(BaseModel):
    """One shipment affected by the cascade."""
    shipment_id: str
    risk_score: float = Field(..., ge=0.0, le=1.0)
    propagation_depth: int = Field(..., description="Hops from the source hub")
    reason: str = Field(..., description="Human-readable explanation")


class CascadeResult(BaseModel):
    """Response from /predict_cascade."""
    disruption: DisruptionEvent
    affected_shipments: List[AffectedShipment]
    total_at_risk: int
    affected_hubs: List[str]
    confidence: float = Field(..., ge=0.0, le=1.0)
    algorithm: str = "weighted_graph_propagation_v1"


# ============================================================
# NEWS PARSING (Gemini)
# ============================================================

class NewsItem(BaseModel):
    """Input for /parse_news — an unstructured headline or snippet."""
    headline: str = Field(..., min_length=5, max_length=1000)


class ParsedDisruption(BaseModel):
    """Response from /parse_news — structured event extracted by Gemini."""
    type: str = Field(..., description="storm/strike/accident/closure/conflict/other/none")
    location: Optional[str] = Field(None, description="Best-guess city, region, or hub")
    severity: float = Field(..., ge=0.0, le=1.0)
    affected_mode: str = Field(default="unknown",
                               description="sea/air/land/multi/unknown")
    confidence: float = Field(..., ge=0.0, le=1.0,
                              description="How confident Gemini is about the extraction")
    raw_response: Optional[str] = Field(None,
                                        description="Gemini's raw text for debugging")


# ============================================================
# ROUTE OPTIMIZATION
# ============================================================

class OptimizeRequest(BaseModel):
    """Input for /optimize_routes."""
    affected_shipment_ids: List[str]
    blocked_hub_ids: List[str] = Field(default_factory=list)


class Reroute(BaseModel):
    """One proposed reroute for a single shipment."""
    shipment_id: str
    original_route: List[str] = Field(..., description="Hub IDs in order")
    new_route: List[str]
    added_distance_km: float
    added_hours: float
    savings_inr: int = Field(..., description="Estimated value preserved")
    reason: str


class OptimizeResult(BaseModel):
    """Response from /optimize_routes."""
    reroutes: List[Reroute]
    count: int
    total_savings_inr: int


# ============================================================
# HEALTH / STATUS
# ============================================================

class HealthStatus(BaseModel):
    status: str
    hubs_loaded: int
    shipments_loaded: int
    gemini_configured: bool
    version: str
