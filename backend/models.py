"""Pydantic request and response models for the MotoMuse backend."""

from pydantic import BaseModel, Field


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
# Geocode models
# ---------------------------------------------------------------------------


class GeocodeRequest(BaseModel):
    """Request body for the /geocode-address endpoint."""

    address: str


class GeocodeResponse(BaseModel):
    """Response from the /geocode-address endpoint."""

    lat: float
    lng: float
    formatted_address: str


# ---------------------------------------------------------------------------
# Home affirming message models
# ---------------------------------------------------------------------------


class HomeAffirmingRequest(BaseModel):
    """Request body for the /home-affirming-message endpoint."""

    address: str
    closest_region: str


class HomeAffirmingResponse(BaseModel):
    """Response from the /home-affirming-message endpoint."""

    message: str


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

    route_type: str = "day_out"
    """Ride type: 'breakfast_run' | 'day_out' | 'overnighter'."""

    destination_lat: float | None = None
    """Latitude of the destination (restaurant or hotel)."""

    destination_lng: float | None = None
    """Longitude of the destination (restaurant or hotel)."""

    destination_name: str | None = None
    """Name of the destination (restaurant or hotel)."""

    riding_area_lat: float | None = None
    """Centre latitude of the selected riding area (day_out only)."""

    riding_area_lng: float | None = None
    """Centre longitude of the selected riding area (day_out only)."""

    riding_area_radius_km: float | None = None
    """Approximate radius of the riding area in km."""

    riding_area_name: str | None = None
    """Name of the selected riding area."""


class RouteWaypoint(BaseModel):
    """A single waypoint on the generated route."""

    lat: float
    lng: float
    street_view_url: str = ""


class SnappedWaypointInfo(BaseModel):
    """Debug info about a waypoint that was snapped to fix a dead-end spur."""

    index: int
    from_lat: float
    from_lng: float
    to_lat: float
    to_lng: float


class DebugAttempt(BaseModel):
    """Debug info for a single route generation attempt."""

    attempt: int
    issues: list[str]
    route_summary: str = ""
    waypoints: list[dict] = Field(default_factory=list)
    prompt_type: str = ""
    prompt_sent: str = ""


class GenerationDebug(BaseModel):
    """Comprehensive debug output for route generation troubleshooting."""

    attempts: int = 0
    passed_validation: bool = False
    original_waypoints: list[dict] = Field(default_factory=list)
    final_waypoints: list[dict] = Field(default_factory=list)
    snapped_waypoints: list[SnappedWaypointInfo] = Field(default_factory=list)
    validation_history: list[DebugAttempt] = Field(default_factory=list)
    route_summary: str = ""
    waypoint_generation_prompt: str = ""
    narrative_prompt: str = ""
    fix_prompts: list[str] = Field(default_factory=list)


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

    debug: GenerationDebug = Field(default_factory=GenerationDebug)

    # -- There-and-back fields (breakfast_run / overnighter) ------------------

    return_polyline: str | None = None
    """Google-encoded polyline for the return leg (different roads)."""

    return_distance_km: float | None = None
    """Return leg distance in kilometres."""

    return_duration_min: int | None = None
    """Return leg estimated duration in minutes."""

    return_waypoints: list[RouteWaypoint] | None = None
    """Waypoints along the return leg."""

    return_street_view_urls: list[str] | None = None
    """Street View images for the return leg."""

    route_type: str = "day_out"
    """The ride type that produced this route."""

    destination_name: str | None = None
    """Name of the destination (restaurant or hotel), if applicable."""
