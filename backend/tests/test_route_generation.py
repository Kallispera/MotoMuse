"""Tests for route_generation.py.

All Google Maps API calls and Claude API calls are mocked. No network access
occurs during these tests.
"""

from unittest.mock import patch, MagicMock

import pytest
import pytest_asyncio

import route_generation
from models import RoutePreferences


# ---------------------------------------------------------------------------
# Shared mock for Street View metadata API (returns coverage OK)
# ---------------------------------------------------------------------------


def _mock_sv_coverage_ok(*args, **kwargs):
    """Mock requests.get that always returns Street View coverage OK."""
    resp = MagicMock()
    # Extract lat/lng from the params to return them in the response.
    params = kwargs.get("params", {})
    loc_str = params.get("location", "0,0")
    parts = loc_str.split(",")
    resp.json.return_value = {
        "status": "OK",
        "location": {"lat": float(parts[0]), "lng": float(parts[1])},
    }
    return resp

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _encode_polyline(coordinates: list[tuple[float, float]]) -> str:
    """Encodes a list of (lat, lng) tuples into a Google-encoded polyline.

    Inverse of _decode_polyline — used in tests to build fixtures.
    """
    encoded = []
    prev_lat = 0
    prev_lng = 0

    for lat, lng in coordinates:
        lat_e5 = round(lat * 1e5)
        lng_e5 = round(lng * 1e5)

        for delta in (lat_e5 - prev_lat, lng_e5 - prev_lng):
            value = ~(delta << 1) if delta < 0 else (delta << 1)
            while value >= 0x20:
                encoded.append(chr((0x20 | (value & 0x1F)) + 63))
                value >>= 5
            encoded.append(chr(value + 63))

        prev_lat = lat_e5
        prev_lng = lng_e5

    return "".join(encoded)


# ---------------------------------------------------------------------------
# Fixtures
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
                    "end_address": "London, UK",
                    "steps": [
                        {
                            "distance": {"value": 5000},
                            "duration": {"value": 300},
                            "html_instructions": "Head north on some road",
                            "start_location": {"lat": 51.5074, "lng": -0.1278},
                            "end_location": {"lat": 51.55, "lng": -0.13},
                            "polyline": {"points": _encode_polyline(
                                [(51.5074, -0.1278), (51.52, -0.129), (51.55, -0.13)]
                            )},
                        },
                        {
                            "distance": {"value": 145000},
                            "duration": {"value": 5100},
                            "html_instructions": "Continue on scenic road",
                            "start_location": {"lat": 51.55, "lng": -0.13},
                            "end_location": {"lat": 51.8, "lng": -0.3},
                            "polyline": {"points": _encode_polyline(
                                [(51.55, -0.13), (51.65, -0.2), (51.8, -0.3)]
                            )},
                        },
                    ],
                }
            ],
            "key_waypoints": [(51.55, -0.13), (51.7, -0.2), (51.8, -0.3)],
        }
    ]


def _make_multi_leg_directions_result():
    """Returns a Directions API result with 3 legs (simulating 2 waypoints)."""
    return [
        {
            "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
            "legs": [
                {
                    "distance": {"value": 24000, "text": "24 km"},
                    "duration": {"value": 1440, "text": "24 mins"},
                    "start_address": "London, UK",
                    "end_address": "Some Town",
                    "steps": [
                        {
                            "distance": {"value": 24000},
                            "duration": {"value": 1440},
                            "html_instructions": "Head north on <b>A road</b>",
                            "start_location": {"lat": 51.5, "lng": -0.1},
                            "end_location": {"lat": 51.7, "lng": -0.2},
                            "polyline": {"points": _encode_polyline(
                                [(51.5, -0.1), (51.6, -0.15), (51.7, -0.2)]
                            )},
                        },
                    ],
                },
                {
                    "distance": {"value": 38000, "text": "38 km"},
                    "duration": {"value": 2280, "text": "38 mins"},
                    "start_address": "Some Town",
                    "end_address": "Another Town",
                    "steps": [
                        {
                            "distance": {"value": 38000},
                            "duration": {"value": 2280},
                            "html_instructions": "Continue on <b>scenic road</b>",
                            "start_location": {"lat": 51.7, "lng": -0.2},
                            "end_location": {"lat": 51.9, "lng": -0.4},
                            "polyline": {"points": _encode_polyline(
                                [(51.7, -0.2), (51.8, -0.3), (51.9, -0.4)]
                            )},
                        },
                    ],
                },
                {
                    "distance": {"value": 38000, "text": "38 km"},
                    "duration": {"value": 2280, "text": "38 mins"},
                    "start_address": "Another Town",
                    "end_address": "London, UK",
                    "steps": [
                        {
                            "distance": {"value": 38000},
                            "duration": {"value": 2280},
                            "html_instructions": "Head south back to start",
                            "start_location": {"lat": 51.9, "lng": -0.4},
                            "end_location": {"lat": 51.5, "lng": -0.1},
                            "polyline": {"points": _encode_polyline(
                                [(51.9, -0.4), (51.7, -0.25), (51.5, -0.1)]
                            )},
                        },
                    ],
                },
            ],
            "key_waypoints": [(51.7, -0.2), (51.9, -0.4), (51.5, -0.1)],
        }
    ]


def _make_urban_directions_result(n_short=15, n_long=5):
    """Returns a Directions result with many short (urban) steps.

    Args:
        n_short: Number of steps shorter than URBAN_SHORT_STEP_THRESHOLD_M.
        n_long: Number of steps longer than the threshold.
    """
    short_steps = [
        {
            "distance": {"value": 150},
            "duration": {"value": 20},
            "html_instructions": f"Turn left onto city street {i}",
            "start_location": {"lat": 52.37 + i * 0.001, "lng": 4.89},
            "end_location": {"lat": 52.37 + (i + 1) * 0.001, "lng": 4.89},
        }
        for i in range(n_short)
    ]
    long_steps = [
        {
            "distance": {"value": 5000},
            "duration": {"value": 300},
            "html_instructions": f"Continue on rural road {i}",
            "start_location": {"lat": 52.5 + i * 0.01, "lng": 4.89},
            "end_location": {"lat": 52.5 + (i + 1) * 0.01, "lng": 4.89},
        }
        for i in range(n_long)
    ]
    all_steps = short_steps + long_steps
    total_distance = sum(s["distance"]["value"] for s in all_steps)
    total_duration = sum(s["duration"]["value"] for s in all_steps)
    return [
        {
            "overview_polyline": {"points": "_p~iF~ps|U_ulLnnqC_mqNvxq`@"},
            "legs": [
                {
                    "distance": {"value": total_distance, "text": f"{total_distance}m"},
                    "duration": {"value": total_duration, "text": f"{total_duration}s"},
                    "start_address": "Amsterdam, NL",
                    "end_address": "Amsterdam, NL",
                    "steps": all_steps,
                }
            ],
        }
    ]


class _MockMapsClient:
    """Minimal mock of googlemaps.Client for testing."""

    def __init__(
        self,
        geocode_result=None,
        directions_result=None,
        reverse_geocode_result=None,
    ):
        self._geocode = (
            geocode_result if geocode_result is not None
            else [{"geometry": {"location": {"lat": 51.5074, "lng": -0.1278}}}]
        )
        self._directions = (
            directions_result if directions_result is not None
            else _make_directions_result()
        )
        self._reverse_geocode = (
            reverse_geocode_result if reverse_geocode_result is not None
            else [{"formatted_address": "London, Greater London, UK"}]
        )

    def geocode(self, address):
        return self._geocode

    def reverse_geocode(self, latlng):
        return self._reverse_geocode

    def directions(self, **kwargs):
        return self._directions


class _MockClaudeClient:
    """Minimal mock of AsyncAnthropic for testing.

    Returns waypoint JSON for all calls except when the prompt contains
    "route description" (which indicates a narrative generation request).
    """

    def __init__(self, waypoint_response=None, narrative_response=None):
        # Default waypoint response: valid JSON array of 5 waypoints (loop).
        self._waypoint_json = waypoint_response or (
            '[{"lat": 51.6, "lng": -0.2}, '
            '{"lat": 51.7, "lng": -0.3}, '
            '{"lat": 51.8, "lng": -0.4}, '
            '{"lat": 51.75, "lng": -0.35}, '
            '{"lat": 51.65, "lng": -0.25}]'
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
                # Detect narrative prompt vs waypoint prompt.
                msg = kwargs.get("messages", [{}])[0].get("content", "")
                if "route description" in msg.lower():
                    content = self._narrative
                else:
                    content = self._waypoint_json

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
# Unit tests: _reverse_geocode_region
# ---------------------------------------------------------------------------


def test_reverse_geocode_region_returns_address():
    maps = _MockMapsClient(
        reverse_geocode_result=[{"formatted_address": "Almere, Flevoland, NL"}]
    )
    result = route_generation._reverse_geocode_region(maps, 52.35, 5.26)
    assert result == "Almere, Flevoland, NL"


def test_reverse_geocode_region_falls_back_on_error():
    """Should return lat,lng string if reverse geocoding fails."""

    class _FailingMaps(_MockMapsClient):
        def reverse_geocode(self, latlng):
            raise RuntimeError("API error")

    maps = _FailingMaps()
    result = route_generation._reverse_geocode_region(maps, 52.35, 5.26)
    assert result == "52.35,5.26"


# ---------------------------------------------------------------------------
# Unit tests: _generate_waypoints
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_generate_waypoints_returns_parsed_coordinates():
    """Claude's JSON response should be parsed into (lat, lng) tuples."""
    claude = _MockClaudeClient(
        waypoint_response=(
            '[{"lat": 52.0, "lng": 5.0}, '
            '{"lat": 52.1, "lng": 5.1}, '
            '{"lat": 52.2, "lng": 5.2}, '
            '{"lat": 52.15, "lng": 5.15}, '
            '{"lat": 52.05, "lng": 5.05}]'
        )
    )
    result = await route_generation._generate_waypoints(
        claude, 52.35, 5.26, "Almere, NL", _PREFS
    )
    assert len(result) == 5
    assert result[0] == (52.0, 5.0)


@pytest.mark.asyncio
async def test_generate_waypoints_raises_on_invalid_json():
    """Should raise ValueError if Claude returns non-JSON."""
    claude = _MockClaudeClient(waypoint_response="I don't know any roads there")
    with pytest.raises(ValueError, match="valid waypoint JSON"):
        await route_generation._generate_waypoints(
            claude, 52.35, 5.26, "Almere, NL", _PREFS
        )


@pytest.mark.asyncio
async def test_generate_waypoints_includes_previous_context():
    """When retrying, the prompt should include previous failure details."""
    captured_prompt = {}

    class _CapturingClaude:
        class _Messages:
            async def create(self, **kwargs):
                captured_prompt["content"] = kwargs["messages"][0]["content"]

                class _Response:
                    class _Content:
                        text = (
                            '[{"lat": 52.0, "lng": 5.0}, '
                            '{"lat": 52.1, "lng": 5.1}, '
                            '{"lat": 52.2, "lng": 5.2}, '
                            '{"lat": 52.15, "lng": 5.15}, '
                            '{"lat": 52.05, "lng": 5.05}]'
                        )
                    content = [_Content()]
                return _Response()

        messages = _Messages()

    claude = _CapturingClaude()
    await route_generation._generate_waypoints(
        claude, 52.35, 5.26, "Almere, NL", _PREFS,
        previous_issues=["Route uses highways for 15% of total distance"],
        route_summary="Leg 1: Almere → Amsterdam (45 km)\n  - Take A6 motorway",
    )

    prompt = captured_prompt["content"]
    assert "PREVIOUS ATTEMPT" in prompt
    assert "highway" in prompt.lower()
    assert "A6" in prompt


# ---------------------------------------------------------------------------
# Unit tests: _extract_json_array
# ---------------------------------------------------------------------------


def test_extract_json_array_pure_json():
    """Should parse a clean JSON array directly."""
    result = route_generation._extract_json_array('[{"lat": 1.0, "lng": 2.0}]')
    assert result == [{"lat": 1.0, "lng": 2.0}]


def test_extract_json_array_with_reasoning():
    """Should extract JSON even when Claude includes reasoning text."""
    text = (
        "I need to plan a route around the Markermeer...\n\n"
        '[{"lat": 52.0, "lng": 5.0}, {"lat": 52.1, "lng": 5.1}]'
    )
    result = route_generation._extract_json_array(text)
    assert result is not None
    assert len(result) == 2
    assert result[0]["lat"] == 52.0


def test_extract_json_array_returns_none_for_invalid():
    """Should return None when no JSON array is found."""
    assert route_generation._extract_json_array("I don't know any roads") is None


# ---------------------------------------------------------------------------
# Unit tests: _extract_route_summary
# ---------------------------------------------------------------------------


def test_extract_route_summary_basic():
    """Should extract leg addresses and step instructions."""
    result = _make_multi_leg_directions_result()[0]
    summary = route_generation._extract_route_summary(result)
    assert "London, UK" in summary
    assert "Some Town" in summary
    assert "A road" in summary
    assert "scenic road" in summary


def test_extract_route_summary_none_input():
    """Should return empty string for None input."""
    assert route_generation._extract_route_summary(None) == ""


def test_extract_route_summary_strips_html():
    """Should strip HTML tags from instructions."""
    result = _make_multi_leg_directions_result()[0]
    summary = route_generation._extract_route_summary(result)
    assert "<b>" not in summary
    assert "</b>" not in summary


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


@patch("route_generation.requests.get", side_effect=_mock_sv_coverage_ok)
def test_get_street_view_urls_returns_up_to_3(mock_get):
    waypoints = [(51.5, -0.1), (51.6, -0.2), (51.7, -0.3), (51.8, -0.4)]
    urls = route_generation._get_street_view_urls(waypoints, "TEST_KEY")
    assert len(urls) == 3


@patch("route_generation.requests.get", side_effect=_mock_sv_coverage_ok)
def test_get_street_view_urls_contain_lat_lng(mock_get):
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
            '{"lat": 51.8, "lng": -0.4}, '
            '{"lat": 51.85, "lng": -0.45}]'
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
    """After 5 failed validations the pipeline should still return a result."""

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


# ---------------------------------------------------------------------------
# Unit tests: _sum_legs
# ---------------------------------------------------------------------------


def test_sum_legs_single_leg():
    """Single-leg result should return that leg's distance and duration."""
    result = _make_directions_result()
    distance_km, duration_min = route_generation._sum_legs(result[0])
    assert distance_km == 150.0
    assert duration_min == 90


def test_sum_legs_multi_leg():
    """Multi-leg result should sum distance and duration across all legs."""
    result = _make_multi_leg_directions_result()
    distance_km, duration_min = route_generation._sum_legs(result[0])
    # 24000 + 38000 + 38000 = 100000 m = 100.0 km
    assert distance_km == 100.0
    # (1440 + 2280 + 2280) // 60 = 6000 // 60 = 100 min
    assert duration_min == 100


# ---------------------------------------------------------------------------
# Unit tests: _validate_route across multiple legs
# ---------------------------------------------------------------------------


def test_validate_route_multi_leg_passes_clean():
    """A clean multi-leg route should pass validation."""
    result = _make_multi_leg_directions_result()
    issues = route_generation._validate_route(result)
    assert issues == []


def test_validate_route_multi_leg_flags_highway_in_later_leg():
    """A motorway step in a later leg should still be caught."""
    result = _make_multi_leg_directions_result()
    # Put a motorway step in the second leg.
    result[0]["legs"][1]["steps"] = [
        {
            "distance": {"value": 38000},
            "html_instructions": "Head north on M1 motorway",
            "start_location": {"lat": 51.7, "lng": -0.2},
            "end_location": {"lat": 51.9, "lng": -0.4},
        },
    ]
    issues = route_generation._validate_route(result)
    assert any("highway" in i.lower() for i in issues)


# ---------------------------------------------------------------------------
# Integration test: multi-leg generate
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_generate_multi_leg_returns_total_distance():
    """generate() should sum distance across all legs, not just the first."""
    maps = _MockMapsClient(
        directions_result=_make_multi_leg_directions_result()
    )
    claude = _MockClaudeClient()

    result = await route_generation.generate(
        _PREFS,
        maps_client=maps,
        claude_client=claude,
    )

    # Total should be 100.0 km (24+38+38), not 24.0 km (first leg only).
    assert result.distance_km == 100.0
    assert result.duration_min == 100


# ---------------------------------------------------------------------------
# Prompt content tests
# ---------------------------------------------------------------------------


def test_waypoint_generation_prompt_includes_key_rules():
    """The waypoint generation prompt should contain critical routing rules."""
    prompt = route_generation._WAYPOINT_GENERATION_PROMPT
    assert "water" in prompt.lower()
    assert "city" in prompt.lower()
    assert "rural" in prompt.lower()
    assert "ACTUAL GEOGRAPHY" in prompt
    assert "ROUTE BETWEEN" in prompt


def test_fix_prompt_includes_route_summary():
    """The fix prompt should include route summary for geographic context."""
    prompt = route_generation._FIX_PROMPT
    assert "route_summary" in prompt
    assert "ACTUAL ROADS" in prompt


# ---------------------------------------------------------------------------
# Unit tests: _decode_polyline
# ---------------------------------------------------------------------------


def test_decode_polyline_known_encoding():
    """Google's example polyline should decode to known coordinates."""
    # Standard Google test vector.
    points = route_generation._decode_polyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    assert len(points) == 3
    assert abs(points[0][0] - 38.5) < 0.01
    assert abs(points[0][1] - (-120.2)) < 0.01
    assert abs(points[1][0] - 40.7) < 0.01
    assert abs(points[1][1] - (-120.95)) < 0.01
    assert abs(points[2][0] - 43.252) < 0.01
    assert abs(points[2][1] - (-126.453)) < 0.01


def test_decode_polyline_empty_string():
    assert route_generation._decode_polyline("") == []


def test_decode_polyline_roundtrip():
    """Encode then decode should return original coordinates (within precision)."""
    original = [(51.5, -0.1), (51.6, -0.2), (51.7, -0.3)]
    encoded = _encode_polyline(original)
    decoded = route_generation._decode_polyline(encoded)
    assert len(decoded) == len(original)
    for (olat, olng), (dlat, dlng) in zip(original, decoded):
        assert abs(olat - dlat) < 0.00002
        assert abs(olng - dlng) < 0.00002


# ---------------------------------------------------------------------------
# Unit tests: _haversine_m
# ---------------------------------------------------------------------------


def test_haversine_known_distance():
    """London to Paris should be roughly 343 km."""
    d = route_generation._haversine_m(51.5074, -0.1278, 48.8566, 2.3522)
    assert abs(d - 343_000) < 5_000  # within 5 km


def test_haversine_same_point():
    d = route_generation._haversine_m(51.5, -0.1, 51.5, -0.1)
    assert d == 0.0


# ---------------------------------------------------------------------------
# Unit tests: _check_polyline_overlap
# ---------------------------------------------------------------------------


def test_check_polyline_overlap_clean_route():
    """A simple loop that doesn't retrace should pass."""
    # Create a square loop: many points going north, east, south, west.
    points = []
    # Go north from 51.0,0.0 to 51.5,0.0 (many steps for enough samples)
    for i in range(100):
        points.append((51.0 + i * 0.005, 0.0))
    # Go east
    for i in range(100):
        points.append((51.5, 0.0 + i * 0.008))
    # Go south
    for i in range(100):
        points.append((51.5 - i * 0.005, 0.8))
    # Go west back to start
    for i in range(100):
        points.append((51.0, 0.8 - i * 0.008))

    encoded = _encode_polyline(points)
    issues = route_generation._check_polyline_overlap(encoded)
    assert issues == []


def test_check_polyline_overlap_detects_doubleback():
    """A route that goes A→B and then B→A should be flagged."""
    points = []
    # Go north from 51.0,0.0 to 51.5,0.0
    for i in range(200):
        points.append((51.0 + i * 0.0025, 0.0))
    # Come right back south
    for i in range(200):
        points.append((51.5 - i * 0.0025, 0.0))

    encoded = _encode_polyline(points)
    issues = route_generation._check_polyline_overlap(encoded)
    assert len(issues) > 0
    assert "doubles back" in issues[0].lower()


# ---------------------------------------------------------------------------
# Unit tests: _compute_road_heading
# ---------------------------------------------------------------------------


def test_compute_road_heading_northward():
    """A polyline going due north should give heading ≈ 0°."""
    points = [(51.0, 0.0), (51.1, 0.0), (51.2, 0.0)]
    heading = route_generation._compute_road_heading(51.05, 0.0, points)
    assert abs(heading) < 5 or abs(heading - 360) < 5  # ≈ 0° (north)


def test_compute_road_heading_eastward():
    """A polyline going due east should give heading ≈ 90°."""
    points = [(51.0, 0.0), (51.0, 0.1), (51.0, 0.2)]
    heading = route_generation._compute_road_heading(51.0, 0.05, points)
    assert abs(heading - 90) < 5


def test_compute_road_heading_empty_polyline():
    """No polyline should return 0 (north) as fallback."""
    assert route_generation._compute_road_heading(51.0, 0.0, []) == 0.0


# ---------------------------------------------------------------------------
# Unit tests: _get_street_view_urls with heading
# ---------------------------------------------------------------------------


@patch("route_generation.requests.get", side_effect=_mock_sv_coverage_ok)
def test_street_view_urls_include_heading(mock_get):
    """URLs should include a heading parameter when a polyline is provided."""
    waypoints = [(51.0, 0.0), (51.1, 0.0)]
    polyline = _encode_polyline([(51.0, 0.0), (51.05, 0.0), (51.1, 0.0)])
    urls = route_generation._get_street_view_urls(
        waypoints, "KEY", overview_polyline=polyline
    )
    assert len(urls) == 2
    for url in urls:
        assert "heading=" in url


@patch("route_generation.requests.get", side_effect=_mock_sv_coverage_ok)
def test_street_view_urls_heading_fallback(mock_get):
    """Without a polyline, heading should default to 0."""
    waypoints = [(51.0, 0.0)]
    urls = route_generation._get_street_view_urls(waypoints, "KEY")
    assert len(urls) == 1
    assert "heading=0" in urls[0]


@pytest.mark.asyncio
async def test_key_waypoints_from_selected_not_steps():
    """_build_and_validate should use input waypoints for key_waypoints."""
    maps = _MockMapsClient()

    waypoints_in = [(51.6, -0.2), (51.7, -0.3), (51.8, -0.4), (51.65, -0.35), (51.55, -0.25)]
    result, issues = await route_generation._build_and_validate(
        maps, 51.5074, -0.1278, waypoints_in, _PREFS
    )
    assert result is not None
    key_wps = result["key_waypoints"]
    # With 5 input waypoints and STREET_VIEW_IMAGE_COUNT=3,
    # should pick 3 evenly spaced from the input list.
    assert len(key_wps) == 3
    # First and last should match input waypoints.
    assert key_wps[0] == waypoints_in[0]
    assert key_wps[-1] == waypoints_in[-1]


# ---------------------------------------------------------------------------
# Unit tests: urban density detection
# ---------------------------------------------------------------------------


def test_validate_route_flags_urban_density():
    """A route with >30% short steps should fail the urban density check."""
    # 15 short steps + 5 long = 75% short — well above the 30% limit.
    result = _make_urban_directions_result(n_short=15, n_long=5)
    issues = route_generation._validate_route(result)
    assert any("urban" in i.lower() for i in issues)


def test_validate_route_passes_rural_route_urban_check():
    """A route with mostly long steps should pass the urban density check."""
    # 2 short steps + 18 long = 10% short — below the 30% limit.
    result = _make_urban_directions_result(n_short=2, n_long=18)
    issues = route_generation._validate_route(result)
    assert not any("urban" in i.lower() for i in issues)


def test_validate_route_urban_density_at_boundary():
    """A route with exactly 30% short steps should pass (limit is >30%)."""
    # 3 short + 7 long = 30% short — at the limit, not over.
    result = _make_urban_directions_result(n_short=3, n_long=7)
    issues = route_generation._validate_route(result)
    assert not any("urban" in i.lower() for i in issues)


# ---------------------------------------------------------------------------
# Unit tests: Dutch / European highway keywords
# ---------------------------------------------------------------------------


def test_validate_route_flags_dutch_motorway():
    """Routes using Dutch A-roads (e.g. A1, A2) should be flagged as highway."""
    result = _make_directions_result()
    result[0]["legs"][0]["steps"] = [
        {
            "distance": {"value": 130000},
            "html_instructions": "Merge onto A1 heading east",
            "start_location": {"lat": 52.3, "lng": 4.9},
            "end_location": {"lat": 52.3, "lng": 6.5},
        },
        {
            "distance": {"value": 20000},
            "html_instructions": "Exit onto N road",
            "start_location": {"lat": 52.3, "lng": 6.5},
            "end_location": {"lat": 52.4, "lng": 6.6},
        },
    ]
    issues = route_generation._validate_route(result)
    assert any("highway" in i.lower() for i in issues)


# ---------------------------------------------------------------------------
# Unit tests: _build_detailed_polyline
# ---------------------------------------------------------------------------


def test_build_detailed_polyline_uses_step_polylines():
    """Should concatenate step-level polylines instead of using overview."""
    result = _make_directions_result()
    detailed = route_generation._build_detailed_polyline(result[0])
    # Should NOT be the overview_polyline.
    assert detailed != result[0]["overview_polyline"]["points"]
    # Decode and verify it has more points (step-level are more detailed).
    points = route_generation._decode_polyline(detailed)
    # We encoded 3 points per step × 2 steps = 6 points, minus 1 shared = 5.
    assert len(points) == 5


def test_build_detailed_polyline_deduplicates_step_boundaries():
    """Shared endpoints between steps should not be duplicated."""
    # Step 1 ends at (51.55, -0.13), step 2 starts at (51.55, -0.13).
    result = _make_directions_result()
    detailed = route_generation._build_detailed_polyline(result[0])
    points = route_generation._decode_polyline(detailed)
    # Check no consecutive duplicate points.
    for i in range(1, len(points)):
        assert points[i] != points[i - 1], f"Duplicate at index {i}"


def test_build_detailed_polyline_multi_leg():
    """Should work across multiple legs."""
    result = _make_multi_leg_directions_result()
    detailed = route_generation._build_detailed_polyline(result[0])
    points = route_generation._decode_polyline(detailed)
    # 3 legs × 3 points per step, minus 2 shared boundaries = 7 points.
    assert len(points) == 7


def test_build_detailed_polyline_falls_back_to_overview():
    """Should use overview_polyline if no step polylines exist."""
    result = _make_directions_result()
    # Remove all step-level polylines.
    for step in result[0]["legs"][0]["steps"]:
        del step["polyline"]
    detailed = route_generation._build_detailed_polyline(result[0])
    assert detailed == result[0]["overview_polyline"]["points"]


# ---------------------------------------------------------------------------
# Unit tests: _encode_polyline (in route_generation module)
# ---------------------------------------------------------------------------


def test_encode_polyline_roundtrip():
    """Encode then decode should return original coordinates."""
    original = [(51.5, -0.1), (51.6, -0.2), (51.7, -0.3)]
    encoded = route_generation._encode_polyline(original)
    decoded = route_generation._decode_polyline(encoded)
    assert len(decoded) == len(original)
    for (olat, olng), (dlat, dlng) in zip(original, decoded):
        assert abs(olat - dlat) < 0.00002
        assert abs(olng - dlng) < 0.00002


# ---------------------------------------------------------------------------
# Unit tests: _check_backtrack_spurs
# ---------------------------------------------------------------------------


def _make_spur_polyline():
    """Creates a polyline with a dead-end spur for testing.

    Route goes east, then north 1km (spur), then south 1km back, then east.
    """
    points = []
    # Main route going east: many steps for enough samples.
    for i in range(50):
        points.append((52.0, 5.0 + i * 0.002))
    # Spur: go north ~1km.
    for i in range(20):
        points.append((52.0 + i * 0.0005, 5.1))
    # Spur: come back south ~1km (same corridor).
    for i in range(20):
        points.append((52.01 - i * 0.0005, 5.1))
    # Continue main route east.
    for i in range(50):
        points.append((52.0, 5.1 + i * 0.002))
    return _encode_polyline(points)


def test_check_backtrack_spurs_clean_loop():
    """A simple loop that doesn't retrace should have no spurs."""
    points = []
    for i in range(100):
        points.append((51.0 + i * 0.005, 0.0))
    for i in range(100):
        points.append((51.5, 0.0 + i * 0.008))
    for i in range(100):
        points.append((51.5 - i * 0.005, 0.8))
    for i in range(100):
        points.append((51.0, 0.8 - i * 0.008))
    encoded = _encode_polyline(points)
    issues = route_generation._check_backtrack_spurs(encoded)
    assert issues == []


def test_check_backtrack_spurs_detects_spur():
    """A route with a dead-end spur should be flagged."""
    encoded = _make_spur_polyline()
    issues = route_generation._check_backtrack_spurs(encoded)
    assert len(issues) > 0
    assert "spur" in issues[0].lower()


def test_check_backtrack_spurs_ignores_short_spur():
    """A very short backtrack (under 500m) should not be flagged."""
    points = []
    # Main route east.
    for i in range(50):
        points.append((52.0, 5.0 + i * 0.002))
    # Tiny spur: go north ~150m and back.
    for i in range(5):
        points.append((52.0 + i * 0.0003, 5.1))
    for i in range(5):
        points.append((52.0015 - i * 0.0003, 5.1))
    # Continue east.
    for i in range(50):
        points.append((52.0, 5.1 + i * 0.002))
    encoded = _encode_polyline(points)
    issues = route_generation._check_backtrack_spurs(encoded)
    assert issues == []


def test_check_backtrack_spurs_empty_polyline():
    """Empty polyline should return no issues."""
    assert route_generation._check_backtrack_spurs("") == []


def test_validate_route_flags_backtrack_spur():
    """_validate_route should flag a route with a dead-end spur."""
    result = _make_directions_result()
    # Replace overview_polyline with one containing a spur.
    result[0]["overview_polyline"]["points"] = _make_spur_polyline()
    issues = route_generation._validate_route(result)
    assert any("spur" in i.lower() for i in issues)


def test_waypoint_prompt_includes_dead_end_rule():
    """The waypoint prompt should warn against dead-end roads."""
    prompt = route_generation._WAYPOINT_GENERATION_PROMPT
    assert "dead-end" in prompt.lower()
    assert "through-road" in prompt.lower()


def test_fix_prompt_includes_spur_guidance():
    """The fix prompt should include spur guidance."""
    prompt = route_generation._FIX_PROMPT
    assert "spur" in prompt.lower()


# ---------------------------------------------------------------------------
# Unit tests: Street View coverage
# ---------------------------------------------------------------------------


def _mock_sv_no_coverage(*args, **kwargs):
    """Mock requests.get that returns no Street View coverage."""
    resp = MagicMock()
    resp.json.return_value = {"status": "ZERO_RESULTS"}
    return resp


@patch("route_generation.requests.get", side_effect=_mock_sv_coverage_ok)
def test_check_street_view_coverage_ok(mock_get):
    """Should return (True, lat, lng) when coverage exists."""
    ok, lat, lng = route_generation._check_street_view_coverage(52.0, 5.0, "KEY")
    assert ok is True
    assert abs(lat - 52.0) < 0.01
    assert abs(lng - 5.0) < 0.01


@patch("route_generation.requests.get", side_effect=_mock_sv_no_coverage)
def test_check_street_view_coverage_no_results(mock_get):
    """Should return (False, original coords) when no coverage."""
    ok, lat, lng = route_generation._check_street_view_coverage(52.0, 5.0, "KEY")
    assert ok is False
    assert lat == 52.0
    assert lng == 5.0


@patch("route_generation.requests.get", side_effect=Exception("Network error"))
def test_check_street_view_coverage_handles_network_error(mock_get):
    """Should return (False, original coords) on network error."""
    ok, lat, lng = route_generation._check_street_view_coverage(52.0, 5.0, "KEY")
    assert ok is False
    assert lat == 52.0


def test_find_street_view_along_route_finds_nearby():
    """Should find coverage at a nearby polyline point."""
    # Dense polyline points (~100m apart) so the search can accumulate distance.
    polyline_points = [(52.0 + i * 0.001, 5.0) for i in range(100)]
    checks = []

    def mock_get(*args, **kwargs):
        resp = MagicMock()
        params = kwargs.get("params", {})
        loc_str = params.get("location", "0,0")
        parts = loc_str.split(",")
        lat = float(parts[0])
        checks.append(lat)
        # Coverage exists only at points beyond lat 52.005.
        if lat > 52.005:
            resp.json.return_value = {
                "status": "OK",
                "location": {"lat": lat, "lng": 5.0},
            }
        else:
            resp.json.return_value = {"status": "ZERO_RESULTS"}
        return resp

    with patch("route_generation.requests.get", side_effect=mock_get):
        ok, lat, lng = route_generation._find_street_view_along_route(
            52.0, 5.0, polyline_points, "KEY"
        )
    assert ok is True
    assert lat > 52.005


def test_find_street_view_along_route_no_coverage():
    """Should return (False, ...) when no coverage found anywhere."""
    polyline_points = [(52.0 + i * 0.005, 5.0) for i in range(20)]

    with patch("route_generation.requests.get", side_effect=_mock_sv_no_coverage):
        ok, lat, lng = route_generation._find_street_view_along_route(
            52.0, 5.0, polyline_points, "KEY"
        )
    assert ok is False


@patch("route_generation.requests.get", side_effect=_mock_sv_no_coverage)
def test_get_street_view_urls_skips_no_coverage(mock_get):
    """Should return fewer URLs when some waypoints have no coverage."""
    waypoints = [(51.5, -0.1), (51.6, -0.2), (51.7, -0.3)]
    urls = route_generation._get_street_view_urls(waypoints, "KEY")
    assert len(urls) == 0


def test_get_street_view_urls_uses_snapped_coordinates():
    """URLs should use the panorama coordinates, not the original waypoint."""

    def mock_get(*args, **kwargs):
        resp = MagicMock()
        # Always snap to 52.001, 5.001 regardless of input.
        resp.json.return_value = {
            "status": "OK",
            "location": {"lat": 52.001, "lng": 5.001},
        }
        return resp

    with patch("route_generation.requests.get", side_effect=mock_get):
        urls = route_generation._get_street_view_urls([(52.0, 5.0)], "KEY")
    assert len(urls) == 1
    assert "52.001" in urls[0]
    assert "5.001" in urls[0]


@patch("route_generation.requests.get", side_effect=_mock_sv_no_coverage)
def test_get_street_view_urls_returns_empty_when_no_coverage(mock_get):
    """Should return empty list when no waypoints have coverage."""
    waypoints = [(51.5, -0.1), (51.6, -0.2)]
    urls = route_generation._get_street_view_urls(waypoints, "KEY")
    assert urls == []
