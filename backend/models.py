"""Pydantic request and response models for the MotoMuse backend."""

from pydantic import BaseModel


class AnalyzeBikeRequest(BaseModel):
    """Request body for the /analyze-bike endpoint."""

    image_url: str


class BikeAnalysisResponse(BaseModel):
    """Full response returned after analysing a motorcycle image.

    Contains structured identification data extracted by GPT vision, plus two
    LLM-generated text fields:
      personality_line  — one-liner about what the bike says about its rider.
      affirming_message — interesting facts about the specific make/model.
    """

    make: str
    model: str
    year: int | None = None
    displacement: str | None = None
    color: str | None = None
    trim: str | None = None
    modifications: list[str] = []
    category: str | None = None
    personality_line: str = ""
    affirming_message: str


class GaragePersonalityRequest(BaseModel):
    """Request body for the /garage-personality endpoint."""

    bikes: list[dict]


class GaragePersonalityResponse(BaseModel):
    """Response from the /garage-personality endpoint."""

    personality: str


# ---------------------------------------------------------------------------
# Route generation models
# ---------------------------------------------------------------------------


class RoutePreferences(BaseModel):
    """Rider preferences for route generation."""

    start_location: str
    """Starting address or 'lat,lng' string."""

    distance_km: int
    """Target ride distance in kilometres (30–300)."""

    curviness: int
    """Desired road curviness on a 1–5 scale."""

    scenery_type: str
    """Preferred scenery: forests | coastline | mountains | mixed."""

    loop: bool
    """True for a circular loop; False for point-to-point."""

    lunch_stop: bool = False
    """Whether to include a restaurant stop at roughly the halfway point."""


class RouteWaypoint(BaseModel):
    """A single waypoint on the generated route."""

    lat: float
    lng: float
    street_view_url: str = ""


class RouteResult(BaseModel):
    """The complete result of a route generation request."""

    encoded_polyline: str
    """Google-encoded polyline string for rendering on the map."""

    distance_km: float
    """Total route distance in kilometres."""

    duration_min: int
    """Estimated riding duration in minutes."""

    waypoints: list[RouteWaypoint]
    """Key waypoints along the route."""

    narrative: str
    """LLM-generated description of the route and why it was chosen."""

    street_view_urls: list[str]
    """Street View Static API URLs at 2–3 scenic waypoints."""
