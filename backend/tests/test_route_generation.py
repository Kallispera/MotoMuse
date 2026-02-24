"""Tests for route_generation.py.

All Google Maps API calls and Claude API calls are mocked. No network access
occurs during these tests.
"""

import pytest
import pytest_asyncio

import route_generation
from models import RoutePreferences

# ---------------------------------------------------------------------------
# Fixtures and helpers
# ---------------------------------------------------------------------------

_PREFS = RoutePreferences(
    start_location="51.5074,-0.1278",
    distance_km=150,
    curviness=3,
    scenery_type="forests",
    loop=True,
)

_PREFS_ONEWAY = RoutePreferences(
    start_location="51.5074,-0.1278",
    distance_km=100,
    curviness=4,
    scenery_type="mountains",
    loop=False,
)


def _make_directions_result(distance_m=150000, duration_s=5400):
    """Returns a minimal Directions API-style result dict."""
    return [
        {
            "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
            "legs": [
                {
                    "distance": {"value": distance_m, "text": "150 km"},
                    "duration": {"value": duration_s, "text": "1 hour 30 mins"},
                    "start_address": "London, UK",
                    "steps": [
                        {
                            "distance": {"value": 5000},
                            "duration": {"value": 300},
                            "html_instructions": "Head north on some road",
                            "start_location": {"lat": 51.5074, "lng": -0.1278},
                            "end_location": {"lat": 51.55, "lng": -0.13},
                        },
                        {
                            "distance": {"value": 145000},
                            "duration": {"value": 5100},
                            "html_instructions": "Continue on scenic road",
                            "start_location": {"lat": 51.55, "lng": -0.13},
                            "end_location": {"lat": 51.8, "lng": -0.3},
                        },
                    ],
                }
            ],
            "key_waypoints": [(51.55, -0.13), (51.7, -0.2), (51.8, -0.3)],
        }
    ]


class _MockMapsClient:
    """Minimal mock of googlemaps.Client for testing."""

    def __init__(
        self,
        geocode_result=None,
        elevation_result=None,
        places_result=None,
        directions_result=None,
    ):
        self._geocode = geocode_result or [
            {"geometry": {"location": {"lat": 51.5074, "lng": -0.1278}}}
        ]
        self._elevation = elevation_result
        self._places = places_result or {"results": []}
        self._directions = (
            directions_result
            if directions_result is not None
            else _make_directions_result()
        )

    def geocode(self, address):
        return self._geocode

    def elevation(self, locations):
        if self._elevation is not None:
            return self._elevation
        return [{"elevation": 50.0} for _ in locations]

    def places_nearby(self, location, radius, keyword, type):  # noqa: A002
        return self._places

    def directions(self, **kwargs):
        return self._directions


class _MockClaudeClient:
    """Minimal mock of AsyncAnthropic for testing."""

    def __init__(self, waypoint_response=None, narrative_response=None):
        # Default waypoint response: valid JSON array.
        self._waypoint_json = waypoint_response or (
            '[{"lat": 51.6, "lng": -0.2}, '
            '{"lat": 51.7, "lng": -0.3}, '
            '{"lat": 51.8, "lng": -0.4}, '
            '{"lat": 51.65, "lng": -0.35}]'
        )
        self._narrative = narrative_response or (
            "This route winds through ancient oak forest, cresting at a ridge "
            "with views of the valley. Expect tight switchbacks on the descent."
        )
        self._call_count = 0

        class _Messages:
            def __init__(inner_self):
                pass

            async def create(inner_self, **kwargs):
                inner_self  # noqa: B018
                self._call_count += 1
                # First call = waypoint selection; subsequent calls = narrative or fix.
                content = (
                    self._waypoint_json
                    if self._call_count == 1
                    else self._narrative
                )

                class _Response:
                    class _Content:
                        text = content

                    content = [_Content()]

                return _Response()

        self.messages = _Messages()


# ---------------------------------------------------------------------------
# Unit tests: _geocode
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_geocode_parses_lat_lng_string():
    """Direct lat,lng strings should be parsed without a Maps API call."""
    maps = _MockMapsClient()
    lat, lng = await route_generation._geocode(maps, "51.5074,-0.1278")
    assert abs(lat - 51.5074) < 0.0001
    assert abs(lng - -0.1278) < 0.0001


@pytest.mark.asyncio
async def test_geocode_calls_api_for_address():
    """Address strings should be resolved via the Maps geocoding API."""
    maps = _MockMapsClient(
        geocode_result=[
            {"geometry": {"location": {"lat": 51.5074, "lng": -0.1278}}}
        ]
    )
    lat, lng = await route_generation._geocode(maps, "London, UK")
    assert abs(lat - 51.5074) < 0.0001


@pytest.mark.asyncio
async def test_geocode_raises_on_empty():
    """Empty location string should raise ValueError."""
    maps = _MockMapsClient()
    with pytest.raises(ValueError, match="must not be empty"):
        await route_generation._geocode(maps, "")


@pytest.mark.asyncio
async def test_geocode_raises_when_api_returns_no_results():
    maps = _MockMapsClient(geocode_result=[])
    with pytest.raises(ValueError, match="Could not geocode"):
        await route_generation._geocode(maps, "Nonexistent Place XYZ")


# ---------------------------------------------------------------------------
# Unit tests: _build_candidate_waypoints
# ---------------------------------------------------------------------------


def test_build_candidate_waypoints_loop_returns_6_points():
    pts = route_generation._build_candidate_waypoints(51.5, -0.1, 150, loop=True)
    assert len(pts) == 6


def test_build_candidate_waypoints_oneway_returns_4_points():
    pts = route_generation._build_candidate_waypoints(51.5, -0.1, 100, loop=False)
    assert len(pts) == 4


def test_build_candidate_waypoints_all_near_start():
    """All waypoints should be within a reasonable distance of the start."""
    pts = route_generation._build_candidate_waypoints(51.5, -0.1, 150, loop=True)
    for lat, lng in pts:
        # With distance=150km, no waypoint should be more than ~40° away.
        assert abs(lat - 51.5) < 5
        assert abs(lng - -0.1) < 10


# ---------------------------------------------------------------------------
# Unit tests: _validate_route
# ---------------------------------------------------------------------------


def test_validate_route_passes_clean_result():
    result = _make_directions_result()
    issues = route_generation._validate_route(result)
    assert issues == []


def test_validate_route_flags_empty_result():
    issues = route_generation._validate_route([])
    assert len(issues) > 0


def test_validate_route_flags_highway_heavy_route():
    """A route where >10% of distance is motorway should fail validation."""
    result = _make_directions_result()
    # Override steps to have a long motorway stretch.
    result[0]["legs"][0]["steps"] = [
        {
            "distance": {"value": 130000},
            "html_instructions": "Head north on M1 motorway",
            "start_location": {"lat": 51.5, "lng": -0.1},
            "end_location": {"lat": 52.0, "lng": -0.2},
        },
        {
            "distance": {"value": 20000},
            "html_instructions": "Turn right on country road",
            "start_location": {"lat": 52.0, "lng": -0.2},
            "end_location": {"lat": 52.1, "lng": -0.3},
        },
    ]
    issues = route_generation._validate_route(result)
    assert any("highway" in i.lower() for i in issues)


# ---------------------------------------------------------------------------
# Unit tests: _get_street_view_urls
# ---------------------------------------------------------------------------


def test_get_street_view_urls_returns_up_to_3():
    waypoints = [(51.5, -0.1), (51.6, -0.2), (51.7, -0.3), (51.8, -0.4)]
    urls = route_generation._get_street_view_urls(waypoints, "TEST_KEY")
    assert len(urls) == 3


def test_get_street_view_urls_contain_lat_lng():
    waypoints = [(51.5074, -0.1278)]
    urls = route_generation._get_street_view_urls(waypoints, "MY_KEY")
    assert len(urls) == 1
    assert "51.5074" in urls[0]
    assert "-0.1278" in urls[0]
    assert "MY_KEY" in urls[0]


def test_get_street_view_urls_empty_waypoints():
    urls = route_generation._get_street_view_urls([], "KEY")
    assert urls == []


# ---------------------------------------------------------------------------
# Unit tests: _bearing
# ---------------------------------------------------------------------------


def test_bearing_north():
    b = route_generation._bearing(0, 0, 1, 0)
    assert abs(b - 0) < 1  # should be roughly north (0°)


def test_bearing_east():
    b = route_generation._bearing(0, 0, 0, 1)
    assert abs(b - 90) < 1  # should be roughly east (90°)


# ---------------------------------------------------------------------------
# Integration test: full generate() pipeline
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_generate_happy_path():
    """Full pipeline should return a valid RouteResult."""
    maps = _MockMapsClient()
    claude = _MockClaudeClient()

    result = await route_generation.generate(
        _PREFS,
        maps_client=maps,
        claude_client=claude,
    )

    assert result.encoded_polyline != ""
    assert result.distance_km > 0
    assert result.duration_min > 0
    assert result.narrative != ""
    assert isinstance(result.street_view_urls, list)
    assert isinstance(result.waypoints, list)


@pytest.mark.asyncio
async def test_generate_one_way_route():
    """One-way preferences should produce a valid result."""
    maps = _MockMapsClient(
        directions_result=_make_directions_result(distance_m=100000, duration_s=3600)
    )
    claude = _MockClaudeClient(
        waypoint_response=(
            '[{"lat": 51.6, "lng": -0.2}, '
            '{"lat": 51.7, "lng": -0.3}, '
            '{"lat": 51.8, "lng": -0.4}]'
        )
    )

    result = await route_generation.generate(
        _PREFS_ONEWAY,
        maps_client=maps,
        claude_client=claude,
    )

    assert result.distance_km > 0


@pytest.mark.asyncio
async def test_generate_retries_on_validation_failure():
    """When the first route fails validation, the pipeline should retry."""

    call_count = {"directions": 0}

    class _HighwayFirstMapsClient(_MockMapsClient):
        def directions(self, **kwargs):
            call_count["directions"] += 1
            if call_count["directions"] == 1:
                # First call: return a motorway-heavy route that fails validation.
                result = _make_directions_result()
                result[0]["legs"][0]["steps"] = [
                    {
                        "distance": {"value": 145000},
                        "html_instructions": "Head north on M1 motorway",
                        "start_location": {"lat": 51.5, "lng": -0.1},
                        "end_location": {"lat": 52.5, "lng": -0.2},
                    },
                    {
                        "distance": {"value": 5000},
                        "html_instructions": "Turn right",
                        "start_location": {"lat": 52.5, "lng": -0.2},
                        "end_location": {"lat": 52.6, "lng": -0.3},
                    },
                ]
                return result
            # Subsequent calls: return a passing route.
            return _make_directions_result()

    maps = _HighwayFirstMapsClient()
    claude = _MockClaudeClient()

    result = await route_generation.generate(
        _PREFS,
        maps_client=maps,
        claude_client=claude,
    )

    assert result.distance_km > 0
    # Should have retried at least once.
    assert call_count["directions"] >= 2


@pytest.mark.asyncio
async def test_generate_falls_back_after_max_retries():
    """After 3 failed validations the pipeline should still return a result."""

    class _AlwaysHighwayMaps(_MockMapsClient):
        def directions(self, **kwargs):
            result = _make_directions_result()
            result[0]["legs"][0]["steps"] = [
                {
                    "distance": {"value": 145000},
                    "html_instructions": "Head on M25 motorway",
                    "start_location": {"lat": 51.5, "lng": -0.1},
                    "end_location": {"lat": 52.5, "lng": -0.2},
                },
                {
                    "distance": {"value": 5000},
                    "html_instructions": "Exit motorway",
                    "start_location": {"lat": 52.5, "lng": -0.2},
                    "end_location": {"lat": 52.6, "lng": -0.3},
                },
            ]
            return result

    maps = _AlwaysHighwayMaps()
    claude = _MockClaudeClient()

    # Should not raise even though validation never passes.
    result = await route_generation.generate(
        _PREFS,
        maps_client=maps,
        claude_client=claude,
    )
    assert result is not None
