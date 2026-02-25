"""Motorcycle route generation pipeline.

Five-step async pipeline:
  1.  Geocode the start location and reverse-geocode to get region context.
  2.  Claude Sonnet generates waypoints using real geographic knowledge.
  3.  Build a navigable route via the Directions API (avoid highways).
  4.  Validate the route polyline; retry up to 5× feeding route details back
      to Claude so it can make informed adjustments.
  5.  Claude Sonnet generates a narrative description of the route.
  6.  Fetch Street View Static images at 2–3 scenic waypoints.

Claude Sonnet (claude-sonnet-4-6) is used for steps 2, 4 retries, and 5.
Google Maps Python client (googlemaps) handles all Google API calls.
"""

import json
import logging
import math
import os
import re
from typing import Any

import requests

import googlemaps
from anthropic import AsyncAnthropic

from models import (
    DebugAttempt,
    GenerationDebug,
    RoutePreferences,
    RouteResult,
    RouteWaypoint,
    SnappedWaypointInfo,
)

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Route-generation rules — all tuneable constants in one place.
# See backend/ROUTE_RULES.md for a plain-English guide to each rule.
# ---------------------------------------------------------------------------

# Claude model used for waypoint selection and narrative generation.
ROUTE_MODEL: str = "claude-sonnet-4-6"

# -- Waypoint generation ---------------------------------------------------
# How many waypoints Claude generates for each route type.
LOOP_WAYPOINT_COUNT: int = 5        # waypoints for a loop route
ONEWAY_WAYPOINT_COUNT: int = 4      # waypoints for a one-way route

# -- Route validation -----------------------------------------------------
# Highway/motorway fraction — fail the route if more than this share of the
# total distance uses motorways.
HIGHWAY_FRACTION_LIMIT: float = 0.10
# Step instruction keywords that indicate a motorway stretch.
HIGHWAY_STEP_KEYWORDS: frozenset = frozenset(
    {
        "motorway", "highway", "freeway",
        # UK motorways
        "m1", "m20", "m25",
        # Dutch / European motorways (A-roads that are motorway-grade)
        "a1", "a2", "a4", "a6", "a7", "a9", "a10", "a27", "a28",
    }
)
# U-turn detection: flag when two consecutive steps are both shorter than
# UTURN_STEP_MAX_M *and* their bearings differ by more than UTURN_BEARING_CHANGE.
UTURN_STEP_MAX_M: int = 200
UTURN_BEARING_CHANGE: int = 150     # degrees
# Polyline overlap detection (large-scale double-backs).
OVERLAP_SAMPLE_INTERVAL_M: int = 300    # sample one point every 300m
OVERLAP_PROXIMITY_THRESHOLD_M: int = 150  # points closer than this "overlap"
OVERLAP_MIN_INDEX_GAP: int = 5          # ignore adjacent samples
OVERLAP_FRACTION_LIMIT: float = 0.03    # fail if >3% of sampled points overlap
# Dead-end spur detection: catch segments where the route goes out along
# a road and comes back along the same corridor.
SPUR_SAMPLE_INTERVAL_M: int = 200       # sample one point every 200m
SPUR_PROXIMITY_M: int = 300             # two points this close may be a spur endpoint
SPUR_MIN_INDEX_GAP: int = 8             # minimum samples apart to be "non-adjacent"
SPUR_PATH_RATIO: float = 5.0            # path_distance / straight_distance threshold
SPUR_MIN_LENGTH_M: int = 500            # ignore spurs shorter than this
# Dead-end spur snapping — detect waypoints where the route U-turns and snap
# them to the branch point where the spur diverges from the main route.
UTURN_BEARING_THRESHOLD: int = 140      # bearing diff (°) to flag U-turn at waypoint
SPUR_CORRIDOR_WIDTH_M: int = 500        # max corridor width for branch-point search
SPUR_SNAP_MIN_LENGTH_M: int = 200       # ignore spurs shorter than this for snapping
# Urban density detection — routes through cities produce many short steps
# with frequent turns. Flag the route if too many steps are short.
URBAN_SHORT_STEP_THRESHOLD_M: int = 300    # steps shorter than this are "urban-style"
URBAN_SHORT_STEP_FRACTION_LIMIT: float = 0.30  # fail if >30% of steps are short
# Maximum validation attempts before accepting the best-effort route.
MAX_ROUTE_ATTEMPTS: int = 5
# On this attempt number and beyond, regenerate completely new waypoints
# instead of adjusting the existing ones.
FRESH_REGEN_ATTEMPT: int = 3

# -- Street View images ---------------------------------------------------
STREET_VIEW_IMAGE_COUNT: int = 3    # images shown on the route preview screen
STREET_VIEW_SIZE: str = "400x240"   # pixel dimensions (width x height)
STREET_VIEW_FOV: int = 90           # horizontal field of view in degrees
STREET_VIEW_PITCH: int = 10         # camera tilt above horizon in degrees
STREET_VIEW_SEARCH_RADIUS_M: int = 2000   # max distance to search for SV coverage
STREET_VIEW_SEARCH_INTERVAL_M: int = 500  # check every 500m along route

# System prompt to force JSON-only responses from Claude.
_JSON_SYSTEM_PROMPT = (
    "You are a geographic route planning API. You respond with ONLY valid JSON "
    "— no markdown, no explanation, no thinking, no commentary. Your entire "
    "response must be a single JSON array."
)

# Internal
_STREETVIEW_BASE = "https://maps.googleapis.com/maps/api/streetview"

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


async def generate(
    prefs: RoutePreferences,
    *,
    maps_client: googlemaps.Client | None = None,
    claude_client: AsyncAnthropic | None = None,
) -> RouteResult:
    """Generates a high-quality motorcycle route matching [prefs].

    Args:
        prefs: Rider preferences (start location, distance, curviness, etc.).
        maps_client: Optional pre-constructed Google Maps client. Created from
            ``GOOGLE_MAPS_API_KEY`` environment variable if omitted.
        claude_client: Optional pre-constructed Anthropic client. Created from
            ``ANTHROPIC_API_KEY`` environment variable if omitted.

    Returns:
        A ``RouteResult`` containing the encoded polyline, distance, duration,
        narrative description, Street View images, and key waypoints.

    Raises:
        ValueError: If required environment variables are missing.
        googlemaps.exceptions.ApiError: On Google Maps API failures.
        anthropic.APIError: On Claude API failures.
    """
    api_key = os.environ.get("GOOGLE_MAPS_API_KEY", "")
    _maps = maps_client or googlemaps.Client(key=api_key)
    _claude = claude_client or AsyncAnthropic(
        api_key=os.environ.get("ANTHROPIC_API_KEY", "")
    )

    logger.info(
        "Route generation started: %s, %dkm, curviness=%d, loop=%s",
        prefs.start_location,
        prefs.distance_km,
        prefs.curviness,
        prefs.loop,
    )

    # Step 1: Geocode start location.
    start_lat, start_lng = await _geocode(_maps, prefs.start_location)
    logger.info("Geocoded start: %f, %f", start_lat, start_lng)

    # Reverse-geocode to get a human-readable region name for Claude.
    start_region = _reverse_geocode_region(_maps, start_lat, start_lng)
    logger.info("Start region: %s", start_region)

    # -- Debug accumulator --------------------------------------------------
    debug = GenerationDebug()

    # Step 2: Claude generates waypoints using geographic knowledge.
    selected, wp_gen_prompt = await _generate_waypoints(
        _claude, start_lat, start_lng, start_region, prefs
    )
    logger.info("Claude generated %d waypoints", len(selected))

    debug.waypoint_generation_prompt = wp_gen_prompt
    debug.original_waypoints = [
        {"lat": lat, "lng": lng} for lat, lng in selected
    ]

    # Steps 3–4: Build route, validate, retry with route feedback.
    directions_result = None
    last_issues: list[str] = []
    all_snapped: list[SnappedWaypointInfo] = []

    for attempt in range(MAX_ROUTE_ATTEMPTS):
        directions_result, last_issues, snap_info = (
            await _build_and_validate(
                _maps, start_lat, start_lng, selected, prefs
            )
        )
        all_snapped.extend(snap_info)

        # Record this attempt in validation history.
        route_summary = ""
        if directions_result is not None:
            route_summary = _extract_route_summary(directions_result)
        debug.validation_history.append(DebugAttempt(
            attempt=attempt + 1,
            issues=list(last_issues),
            route_summary=route_summary,
            waypoints=[{"lat": lat, "lng": lng} for lat, lng in selected],
        ))

        if not last_issues:
            logger.info("Route passed validation on attempt %d", attempt + 1)
            break
        logger.warning(
            "Attempt %d failed validation: %s", attempt + 1, last_issues
        )
        if attempt < MAX_ROUTE_ATTEMPTS - 1:
            if attempt + 1 >= FRESH_REGEN_ATTEMPT:
                # Later retries: ask Claude to generate entirely new waypoints
                # with the failed route as negative context.
                logger.info(
                    "Attempt %d: full waypoint regeneration", attempt + 2
                )
                selected, regen_prompt = await _generate_waypoints(
                    _claude, start_lat, start_lng, start_region, prefs,
                    previous_issues=last_issues,
                    route_summary=route_summary,
                )
                debug.fix_prompts.append(regen_prompt)
                # Update the last history entry with prompt info.
                debug.validation_history[-1].prompt_type = "regenerate"
                debug.validation_history[-1].prompt_sent = regen_prompt
            else:
                # Early retries: adjust existing waypoints using route context.
                selected, fix_prompt = await _fix_waypoints(
                    _claude, selected, last_issues, prefs,
                    route_summary=route_summary,
                )
                debug.fix_prompts.append(fix_prompt)
                debug.validation_history[-1].prompt_type = "fix"
                debug.validation_history[-1].prompt_sent = fix_prompt

    if directions_result is None:
        raise RuntimeError("Directions API returned no result after retries.")

    debug.attempts = len(debug.validation_history)
    debug.passed_validation = not last_issues
    debug.final_waypoints = [
        {"lat": lat, "lng": lng} for lat, lng in selected
    ]
    debug.snapped_waypoints = all_snapped
    if directions_result is not None:
        debug.route_summary = _extract_route_summary(directions_result)

    # Step 5: Narrative.
    narrative, narrative_prompt = await _generate_narrative(
        _claude, directions_result, prefs
    )
    debug.narrative_prompt = narrative_prompt

    # Step 6: Street View images.
    # Use detailed step-level polylines for accurate road-following rendering.
    # The overview_polyline is too simplified and cuts through fields/water.
    encoded_polyline = _build_detailed_polyline(directions_result)
    street_view_urls = _get_street_view_urls(
        directions_result.get("key_waypoints", selected[:3]),
        api_key,
        overview_polyline=encoded_polyline,
    )

    # Build final result.
    # directions_result is already result[0] from the Directions API response
    # (a single route dict), so index "legs" directly — not "routes"][0].
    distance_km, duration_min = _sum_legs(directions_result)

    waypoints = [
        RouteWaypoint(lat=lat, lng=lng) for lat, lng in selected
    ]

    logger.info(
        "Route generation complete: %.1fkm, %dmin", distance_km, duration_min
    )

    return RouteResult(
        encoded_polyline=encoded_polyline,
        distance_km=round(distance_km, 1),
        duration_min=duration_min,
        waypoints=waypoints,
        narrative=narrative,
        street_view_urls=street_view_urls,
        debug=debug,
    )


# ---------------------------------------------------------------------------
# Step 1: Geocoding
# ---------------------------------------------------------------------------


async def _geocode(
    maps_client: googlemaps.Client, location: str
) -> tuple[float, float]:
    """Returns (lat, lng) for the given address or coordinate string.

    If ``location`` is already in `lat,lng` format the values are parsed
    directly without a network call.
    """
    location = location.strip()
    if not location:
        raise ValueError("start_location must not be empty.")

    # Try to parse "lat,lng" directly.
    parts = location.split(",")
    if len(parts) == 2:
        try:
            return float(parts[0].strip()), float(parts[1].strip())
        except ValueError:
            pass

    # Fall back to geocoding.
    result = maps_client.geocode(location)
    if not result:
        raise ValueError(f"Could not geocode location: {location!r}")
    loc = result[0]["geometry"]["location"]
    return float(loc["lat"]), float(loc["lng"])


def _reverse_geocode_region(
    maps_client: googlemaps.Client, lat: float, lng: float
) -> str:
    """Returns a human-readable region string for the given coordinates.

    Used to give Claude geographic context (e.g. "Almere, Flevoland, Netherlands")
    so it can reason about water bodies, cities, and road networks in the area.
    Returns a best-effort string; falls back to "lat,lng" on failure.
    """
    try:
        results = maps_client.reverse_geocode((lat, lng))
        if results:
            return results[0].get("formatted_address", f"{lat},{lng}")
    except Exception:  # noqa: BLE001
        pass
    return f"{lat},{lng}"


# ---------------------------------------------------------------------------
# Step 2: Claude-based waypoint generation
# ---------------------------------------------------------------------------

_WAYPOINT_GENERATION_PROMPT = """\
You are planning a motorcycle route.

Start location: {start_region} (coordinates: {start_lat}, {start_lng})

Route requirements:
- Distance: approximately {distance_km} km
- Curviness preference: {curviness}/5 (1=relaxed straight roads, 5=maximum twisties)
- Scenery type: {scenery_type}
- Route type: {route_type}

Generate exactly {n_waypoints} intermediate waypoints for this route, in riding \
order. The route will start and {loop_description} the start coordinates — do \
NOT include the start/end point in your waypoints.

CRITICAL RULES:
1. Every waypoint MUST be on or within 100m of a real, paved road that exists \
in the region. Use your knowledge of actual road networks.
2. NEVER place a waypoint in a lake, sea, river, reservoir, or any body of \
water. Know where water bodies are in this region.
3. NEVER place a waypoint in the centre of a city with population over 50,000. \
Small towns and villages are fine.
4. Consecutive waypoints must be connectable via rural or secondary roads \
WITHOUT passing through major cities (pop > 100k) or crossing large water \
bodies.
5. For a loop: the waypoints should form a flowing circuit. The last waypoint \
should naturally lead back toward the start via rural roads.
6. For one-way: waypoints should progress steadily away from the start.
7. Think about the ACTUAL GEOGRAPHY of the region — you know where the roads, \
water bodies, forests, mountains, and cities are. Use that knowledge.
8. Prefer scenic motorcycle-friendly roads: mountain passes, coastal roads, \
forest routes, dyke roads, country lanes, secondary highways.
9. Think about the ROUTE BETWEEN waypoints — the road that connects them \
matters as much as the waypoints themselves. Avoid forcing connections through \
urban areas.
10. Space waypoints so the total route distance (via roads) roughly matches \
the requested distance.
11. NEVER place a waypoint at the end of a dead-end road, cul-de-sac, or \
road that only has one way in and out (e.g. waterfront lookout points, \
harbour parking areas, nature reserve access roads). Every waypoint must be \
on a through-road that connects to other roads in at least two directions.
{previous_context}
Return ONLY a JSON array of {n_waypoints} waypoints: \
[{{"lat": ..., "lng": ...}}, ...]
"""


def _extract_json_array(text: str) -> list[dict] | None:
    """Extracts a JSON array from text that may contain extra commentary.

    Claude sometimes returns reasoning text before or after the JSON.
    This function finds and parses the first JSON array in the response.
    """
    # Try the whole string first (fastest path).
    text = text.strip()
    try:
        parsed = json.loads(text)
        if isinstance(parsed, list):
            return parsed
    except (json.JSONDecodeError, ValueError):
        pass

    # Find the first [...] block in the text.
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if match:
        try:
            parsed = json.loads(match.group())
            if isinstance(parsed, list):
                return parsed
        except (json.JSONDecodeError, ValueError):
            pass

    return None


async def _generate_waypoints(
    claude_client: AsyncAnthropic,
    start_lat: float,
    start_lng: float,
    start_region: str,
    prefs: RoutePreferences,
    *,
    previous_issues: list[str] | None = None,
    route_summary: str | None = None,
) -> tuple[list[tuple[float, float]], str]:
    """Uses Claude to generate waypoints based on real geographic knowledge.

    Unlike the old geometric candidate approach, Claude uses its knowledge of
    actual road networks, water bodies, and cities to place waypoints on
    real roads in suitable locations.

    Args:
        previous_issues: Validation issues from a previous attempt (for retries).
        route_summary: Human-readable summary of the failed route (road names,
            cities) so Claude can see exactly what went wrong.

    Returns:
        Tuple of (waypoints, prompt_sent) for debug logging.
    """
    n_waypoints = (
        LOOP_WAYPOINT_COUNT if prefs.loop else ONEWAY_WAYPOINT_COUNT
    )
    route_type = "loop (return to start)" if prefs.loop else "one-way"

    previous_context = ""
    if previous_issues:
        issues_text = "\n".join(f"  - {issue}" for issue in previous_issues)
        previous_context = (
            f"\nA PREVIOUS ATTEMPT at this route failed validation:\n"
            f"{issues_text}\n"
        )
        if route_summary:
            previous_context += (
                f"\nThe failed route went through these roads/areas:\n"
                f"{route_summary}\n"
                f"\nGenerate COMPLETELY DIFFERENT waypoints that avoid the "
                f"problematic areas listed above.\n"
            )

    loop_description = "return to" if prefs.loop else "end away from"
    prompt = _WAYPOINT_GENERATION_PROMPT.format(
        start_region=start_region,
        start_lat=start_lat,
        start_lng=start_lng,
        distance_km=prefs.distance_km,
        curviness=prefs.curviness,
        scenery_type=prefs.scenery_type,
        route_type=route_type,
        n_waypoints=n_waypoints,
        loop_description=loop_description,
        previous_context=previous_context,
    )

    logger.info("Requesting waypoint generation from Claude")
    response = await claude_client.messages.create(
        model=ROUTE_MODEL,
        max_tokens=512,
        system=_JSON_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = response.content[0].text.strip()
    logger.info("Claude waypoint response: %s", raw[:300])

    parsed = _extract_json_array(raw)
    if parsed is not None:
        try:
            return [(float(p["lat"]), float(p["lng"])) for p in parsed], prompt
        except (KeyError, TypeError, ValueError):
            logger.warning("Waypoint JSON missing lat/lng keys: %s", raw[:200])

    raise ValueError("Claude did not return valid waypoint JSON.")


# ---------------------------------------------------------------------------
# Step 6: Build directions + Step 7: Validate
# ---------------------------------------------------------------------------


async def _build_and_validate(
    maps_client: googlemaps.Client,
    start_lat: float,
    start_lng: float,
    waypoints: list[tuple[float, float]],
    prefs: RoutePreferences,
) -> tuple[dict[str, Any] | None, list[str], list[SnappedWaypointInfo]]:
    """Builds a route via the Directions API and validates the result.

    Returns:
        Tuple of (directions_result, list_of_validation_issues,
        list_of_snapped_waypoint_info).
        If the API call fails, directions_result is None and issues contains
        the error description.
    """
    snapped_info: list[SnappedWaypointInfo] = []

    origin = f"{start_lat},{start_lng}"
    destination = origin if prefs.loop else (
        f"{waypoints[-1][0]},{waypoints[-1][1]}" if waypoints else origin
    )
    intermediate = waypoints[:-1] if not prefs.loop else waypoints
    wp_strs = [f"{lat},{lng}" for lat, lng in intermediate]

    try:
        result = maps_client.directions(
            origin=origin,
            destination=destination,
            waypoints=wp_strs,
            mode="driving",
            avoid=["highways", "tolls"],
            optimize_waypoints=False,
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Directions API error: %s", exc)
        return None, [f"Directions API error: {exc}"], snapped_info

    if not result:
        return None, ["Directions API returned no routes."], snapped_info

    # --- Spur snapping: detect U-turn waypoints and snap them to branch
    # points before running validation.  One re-request at most. ----------
    if len(result[0].get("legs", [])) > 1:
        new_intermediate, snapped = _snap_spur_waypoints(
            result[0], intermediate,
        )
        if snapped:
            logger.info(
                "Spur snapping: re-requesting with %d snapped waypoint(s)",
                len(snapped),
            )
            # Record snapping details for debug output.
            for idx in snapped:
                old = intermediate[idx]
                new = new_intermediate[idx]
                snapped_info.append(SnappedWaypointInfo(
                    index=idx,
                    from_lat=old[0], from_lng=old[1],
                    to_lat=new[0], to_lng=new[1],
                ))

            wp_strs = [f"{lat},{lng}" for lat, lng in new_intermediate]
            try:
                snap_result = maps_client.directions(
                    origin=origin,
                    destination=destination,
                    waypoints=wp_strs,
                    mode="driving",
                    avoid=["highways", "tolls"],
                    optimize_waypoints=False,
                )
            except Exception as exc:  # noqa: BLE001
                logger.error("Directions API error (spur snap): %s", exc)
                snap_result = None

            if snap_result:
                result = snap_result
                # Update waypoints for downstream key_waypoints selection.
                if prefs.loop:
                    waypoints = list(new_intermediate)
                    intermediate = waypoints
                else:
                    waypoints = list(new_intermediate) + [waypoints[-1]]
                    intermediate = new_intermediate

    issues = _validate_route(result)
    # Attach the selected scenic waypoints for Street View, evenly spaced.
    if result:
        n = len(waypoints)
        if n <= STREET_VIEW_IMAGE_COUNT:
            key_wps = list(waypoints)
        else:
            idxs = [
                round(i * (n - 1) / (STREET_VIEW_IMAGE_COUNT - 1))
                for i in range(STREET_VIEW_IMAGE_COUNT)
            ]
            key_wps = [waypoints[i] for i in idxs]
        result[0]["key_waypoints"] = key_wps

    return result[0] if result else None, issues, snapped_info


def _validate_route(result: list[dict[str, Any]]) -> list[str]:
    """Validates the Directions API result against quality rules.

    Checks:
    - Highway/motorway steps not exceeding 10% of total distance.
    - No obvious U-turns (bearing reversal within short steps).
    - Polyline overlap detection for large-scale double-backs.
    - Urban density detection (too many short steps = city routing).

    Returns:
        A list of human-readable issue descriptions. Empty = valid.
    """
    issues: list[str] = []
    if not result:
        return ["No route returned by Directions API."]

    route = result[0]
    steps = []
    total_distance = 0
    for leg in route["legs"]:
        steps.extend(leg["steps"])
        total_distance += leg["distance"]["value"]

    # Check for highway-dominant stretches.
    if total_distance > 0:
        highway_distance = sum(
            s["distance"]["value"]
            for s in steps
            if _is_highway_step(s)
        )
        highway_pct = highway_distance / total_distance
        if highway_pct > HIGHWAY_FRACTION_LIMIT:
            issues.append(
                f"Route uses highways for {highway_pct:.0%} of total distance "
                f"(limit: 10%)."
            )

    # Check for U-turns: bearing reversal on consecutive short steps.
    for i in range(1, len(steps)):
        prev = steps[i - 1]
        curr = steps[i]
        if (
            prev["distance"]["value"] < UTURN_STEP_MAX_M
            and curr["distance"]["value"] < UTURN_STEP_MAX_M
        ):
            prev_bear = _bearing(
                prev["start_location"]["lat"], prev["start_location"]["lng"],
                prev["end_location"]["lat"], prev["end_location"]["lng"],
            )
            curr_bear = _bearing(
                curr["start_location"]["lat"], curr["start_location"]["lng"],
                curr["end_location"]["lat"], curr["end_location"]["lng"],
            )
            diff = abs(prev_bear - curr_bear)
            if diff > 180:
                diff = 360 - diff
            if diff > UTURN_BEARING_CHANGE:
                issues.append(
                    f"Possible U-turn detected at step {i} "
                    f"(bearing change {diff:.0f}°)."
                )
                break  # One U-turn flag is enough to trigger retry.

    # Check for large-scale double-backs via polyline overlap.
    overview = route.get("overview_polyline", {}).get("points", "")
    if overview:
        issues.extend(_check_polyline_overlap(overview))
        issues.extend(_check_backtrack_spurs(overview))

    # Check for urban density: too many short steps indicate city routing.
    if steps:
        short_step_count = sum(
            1 for s in steps
            if s["distance"]["value"] < URBAN_SHORT_STEP_THRESHOLD_M
        )
        short_fraction = short_step_count / len(steps)
        if short_fraction > URBAN_SHORT_STEP_FRACTION_LIMIT:
            issues.append(
                f"Route appears to pass through urban areas: "
                f"{short_fraction:.0%} of steps are shorter than "
                f"{URBAN_SHORT_STEP_THRESHOLD_M}m "
                f"(limit: {URBAN_SHORT_STEP_FRACTION_LIMIT:.0%})."
            )

    return issues


def _sum_legs(directions_result: dict[str, Any]) -> tuple[float, int]:
    """Sums distance (km) and duration (minutes) across all legs.

    The Directions API returns one leg per segment between waypoints.
    A route with N intermediate waypoints has N+1 legs.
    """
    total_distance_m = sum(
        leg["distance"]["value"] for leg in directions_result["legs"]
    )
    total_duration_s = sum(
        leg["duration"]["value"] for leg in directions_result["legs"]
    )
    return total_distance_m / 1000, total_duration_s // 60


def _is_highway_step(step: dict[str, Any]) -> bool:
    """Returns True if the step's HTML instructions mention a motorway."""
    instructions = step.get("html_instructions", "").lower()
    return any(kw in instructions for kw in HIGHWAY_STEP_KEYWORDS)


def _bearing(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Returns the initial bearing in degrees (0–360) from point 1 to point 2."""
    lat1, lat2 = math.radians(lat1), math.radians(lat2)
    dlng = math.radians(lng2 - lng1)
    x = math.sin(dlng) * math.cos(lat2)
    y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlng)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Returns the great-circle distance in metres between two points."""
    earth_r = 6_371_000  # metres
    lat1_r, lat2_r = math.radians(lat1), math.radians(lat2)
    dlat = lat2_r - lat1_r
    dlng = math.radians(lng2 - lng1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1_r) * math.cos(lat2_r) * math.sin(dlng / 2) ** 2
    )
    return earth_r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def _decode_polyline(encoded: str) -> list[tuple[float, float]]:
    """Decodes a Google-encoded polyline string to a list of (lat, lng) points.

    Implements the standard Google polyline encoding algorithm.
    See: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    """
    result: list[tuple[float, float]] = []
    index = 0
    lat = 0
    lng = 0

    while index < len(encoded):
        # Decode latitude delta.
        shift = 0
        value = 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            value |= (b & 0x1F) << shift
            shift += 5
            if b < 0x20:
                break
        lat += ~(value >> 1) if (value & 1) else (value >> 1)

        # Decode longitude delta.
        shift = 0
        value = 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            value |= (b & 0x1F) << shift
            shift += 5
            if b < 0x20:
                break
        lng += ~(value >> 1) if (value & 1) else (value >> 1)

        result.append((lat / 1e5, lng / 1e5))

    return result


def _encode_polyline(coordinates: list[tuple[float, float]]) -> str:
    """Encodes a list of (lat, lng) tuples into a Google-encoded polyline."""
    encoded: list[str] = []
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


def _build_detailed_polyline(directions_result: dict[str, Any]) -> str:
    """Builds a high-resolution encoded polyline from step-level polylines.

    The Directions API overview_polyline is heavily simplified and can cut
    through fields, water, and buildings. Each step has its own polyline that
    follows the actual road geometry. This function decodes all step polylines,
    concatenates the points (removing duplicates at step boundaries), and
    re-encodes the result.

    Falls back to the overview_polyline if no step polylines are available.
    """
    all_points: list[tuple[float, float]] = []
    for leg in directions_result.get("legs", []):
        for step in leg.get("steps", []):
            step_encoded = step.get("polyline", {}).get("points", "")
            if not step_encoded:
                continue
            step_points = _decode_polyline(step_encoded)
            if not step_points:
                continue
            # Skip the first point if it duplicates the last point we added
            # (step boundaries share endpoints).
            if all_points and step_points[0] == all_points[-1]:
                step_points = step_points[1:]
            all_points.extend(step_points)

    if all_points:
        return _encode_polyline(all_points)

    # Fallback to overview_polyline if step polylines are missing.
    return directions_result.get("overview_polyline", {}).get("points", "")


def _check_polyline_overlap(overview_polyline: str) -> list[str]:
    """Detects large-scale double-backs by checking if the route overlaps itself.

    Decodes the overview polyline, samples points at regular intervals, then
    checks whether any non-adjacent sampled points are geographically close
    (indicating the route retraces the same corridor).
    """
    points = _decode_polyline(overview_polyline)
    if len(points) < 2:
        return []

    # Sample points at approximately OVERLAP_SAMPLE_INTERVAL_M intervals.
    sampled = [points[0]]
    accumulated_m = 0.0
    for i in range(1, len(points)):
        d = _haversine_m(
            points[i - 1][0], points[i - 1][1],
            points[i][0], points[i][1],
        )
        accumulated_m += d
        if accumulated_m >= OVERLAP_SAMPLE_INTERVAL_M:
            sampled.append(points[i])
            accumulated_m = 0.0

    if len(sampled) < OVERLAP_MIN_INDEX_GAP * 2:
        return []  # Route too short to meaningfully check.

    # Count how many sampled points are close to a non-adjacent sampled point.
    overlap_count = 0
    for i in range(len(sampled)):
        for j in range(i + OVERLAP_MIN_INDEX_GAP, len(sampled)):
            dist = _haversine_m(
                sampled[i][0], sampled[i][1],
                sampled[j][0], sampled[j][1],
            )
            if dist < OVERLAP_PROXIMITY_THRESHOLD_M:
                overlap_count += 1
                break  # One overlap per point is enough.

    fraction = overlap_count / len(sampled) if sampled else 0
    if fraction > OVERLAP_FRACTION_LIMIT:
        return [
            f"Route doubles back on itself: {fraction:.0%} of sampled points "
            f"overlap with non-adjacent segments "
            f"(limit: {OVERLAP_FRACTION_LIMIT:.0%})."
        ]
    return []


def _check_backtrack_spurs(overview_polyline: str) -> list[str]:
    """Detects dead-end spurs where the route backtracks along the same corridor.

    Walks through sampled polyline points and flags segments where two
    non-adjacent points are geographically close but the path between them
    is disproportionately long (indicating a there-and-back pattern).
    """
    points = _decode_polyline(overview_polyline)
    if len(points) < 2:
        return []

    # Sample points at regular intervals.
    sampled = [points[0]]
    accumulated_m = 0.0
    for i in range(1, len(points)):
        d = _haversine_m(
            points[i - 1][0], points[i - 1][1],
            points[i][0], points[i][1],
        )
        accumulated_m += d
        if accumulated_m >= SPUR_SAMPLE_INTERVAL_M:
            sampled.append(points[i])
            accumulated_m = 0.0

    if len(sampled) < SPUR_MIN_INDEX_GAP * 2:
        return []  # Route too short to meaningfully check.

    # Pre-compute distances between consecutive samples for fast path-distance
    # lookups.
    seg_dist = []
    for i in range(1, len(sampled)):
        seg_dist.append(_haversine_m(
            sampled[i - 1][0], sampled[i - 1][1],
            sampled[i][0], sampled[i][1],
        ))

    issues: list[str] = []
    for i in range(len(sampled)):
        for j in range(i + SPUR_MIN_INDEX_GAP, len(sampled)):
            # Skip start/end overlap for loops (first and last few samples).
            if i < SPUR_MIN_INDEX_GAP and j > len(sampled) - SPUR_MIN_INDEX_GAP:
                continue

            straight = _haversine_m(
                sampled[i][0], sampled[i][1],
                sampled[j][0], sampled[j][1],
            )
            if straight > SPUR_PROXIMITY_M:
                continue

            # Points are close — compute path distance along the route.
            path_dist = sum(seg_dist[i:j])
            spur_length = path_dist / 2

            if straight < 1:
                # Avoid division by zero — points are essentially identical.
                ratio = path_dist  # Treat as infinite ratio.
            else:
                ratio = path_dist / straight

            if ratio > SPUR_PATH_RATIO and spur_length > SPUR_MIN_LENGTH_M:
                issues.append(
                    f"Dead-end spur detected: route backtracks ~{spur_length / 1000:.1f}km "
                    f"near ({sampled[i][0]:.3f}, {sampled[i][1]:.3f})."
                )
                return issues  # One spur is enough to trigger a retry.

    return issues


# ---------------------------------------------------------------------------
# Dead-end spur snapping — detect U-turn waypoints, find branch points,
# and snap waypoints onto the main route to eliminate spurs.
# ---------------------------------------------------------------------------


def _decode_leg_polyline(leg: dict[str, Any]) -> list[tuple[float, float]]:
    """Decodes all step polylines in a single leg into a point list."""
    all_points: list[tuple[float, float]] = []
    for step in leg.get("steps", []):
        step_encoded = step.get("polyline", {}).get("points", "")
        if not step_encoded:
            continue
        step_points = _decode_polyline(step_encoded)
        if not step_points:
            continue
        if all_points and step_points[0] == all_points[-1]:
            step_points = step_points[1:]
        all_points.extend(step_points)
    return all_points


def _detect_uturn_waypoints(
    directions_result: dict[str, Any],
) -> list[int]:
    """Detects waypoints where the route performs a U-turn (dead-end spur).

    For a route with N intermediate waypoints there are N+1 legs.
    Leg boundary *i* (between leg i and leg i+1) corresponds to intermediate
    waypoint *i*.  A U-turn is detected when the approach bearing (last step
    of leg i) and departure bearing (first step of leg i+1) differ by more
    than ``UTURN_BEARING_THRESHOLD`` degrees.
    """
    legs = directions_result.get("legs", [])
    uturn_indices: list[int] = []

    for i in range(len(legs) - 1):
        # --- approach bearing: last step of incoming leg ---
        incoming_steps = legs[i].get("steps", [])
        if not incoming_steps:
            continue
        last_step = incoming_steps[-1]
        a_start = last_step.get("start_location", {})
        a_end = last_step.get("end_location", {})
        # Guard: skip degenerate zero-length steps.
        if (
            a_start.get("lat") == a_end.get("lat")
            and a_start.get("lng") == a_end.get("lng")
        ):
            continue

        # --- departure bearing: first step of outgoing leg ---
        outgoing_steps = legs[i + 1].get("steps", [])
        if not outgoing_steps:
            continue
        first_step = outgoing_steps[0]
        d_start = first_step.get("start_location", {})
        d_end = first_step.get("end_location", {})
        if (
            d_start.get("lat") == d_end.get("lat")
            and d_start.get("lng") == d_end.get("lng")
        ):
            continue

        approach = _bearing(
            a_start["lat"], a_start["lng"], a_end["lat"], a_end["lng"],
        )
        depart = _bearing(
            d_start["lat"], d_start["lng"], d_end["lat"], d_end["lng"],
        )

        diff = abs(approach - depart)
        if diff > 180:
            diff = 360 - diff
        if diff > UTURN_BEARING_THRESHOLD:
            uturn_indices.append(i)

    return uturn_indices


def _find_branch_point(
    directions_result: dict[str, Any],
    waypoint_idx: int,
) -> tuple[float, float] | None:
    """Finds the branch point where a dead-end spur diverges from the main route.

    Decodes step-level polylines for the two legs surrounding the U-turn
    waypoint.  Walks outward from the waypoint position along both legs
    simultaneously.  While the two paths remain within ``SPUR_CORRIDOR_WIDTH_M``
    of each other, we are still in the spur corridor.  The last pair of close
    points before they diverge is the branch point.

    Returns ``(lat, lng)`` of the branch point, or ``None`` if the spur is too
    short or no clear branch point is found.
    """
    legs = directions_result.get("legs", [])
    if waypoint_idx + 1 >= len(legs):
        return None

    # Decode the approach leg (ends at waypoint) and departure leg (starts at
    # waypoint).  Reverse the approach leg so index 0 = waypoint.
    approach_pts = _decode_leg_polyline(legs[waypoint_idx])
    depart_pts = _decode_leg_polyline(legs[waypoint_idx + 1])

    if len(approach_pts) < 2 or len(depart_pts) < 2:
        return None

    approach_rev = list(reversed(approach_pts))

    last_close_a = approach_rev[0]
    last_close_d = depart_pts[0]
    spur_length_m = 0.0

    max_steps = min(len(approach_rev), len(depart_pts))
    for step in range(1, max_steps):
        a_pt = approach_rev[step]
        d_pt = depart_pts[step]

        dist = _haversine_m(a_pt[0], a_pt[1], d_pt[0], d_pt[1])

        if dist < SPUR_CORRIDOR_WIDTH_M:
            # Still in the spur corridor — update branch point candidate.
            last_close_a = a_pt
            last_close_d = d_pt
            # Track distance walked from the waypoint for spur length.
            spur_length_m += _haversine_m(
                approach_rev[step - 1][0], approach_rev[step - 1][1],
                a_pt[0], a_pt[1],
            )
        else:
            # Paths have diverged — we found the branch point.
            break

    if spur_length_m < SPUR_SNAP_MIN_LENGTH_M:
        return None  # Spur too short; not worth snapping.

    branch_lat = (last_close_a[0] + last_close_d[0]) / 2
    branch_lng = (last_close_a[1] + last_close_d[1]) / 2
    return (branch_lat, branch_lng)


def _snap_spur_waypoints(
    directions_result: dict[str, Any],
    waypoints: list[tuple[float, float]],
) -> tuple[list[tuple[float, float]], list[int]]:
    """Replaces dead-end U-turn waypoints with their branch points.

    Returns (new_waypoints, snapped_indices).  ``new_waypoints`` has the same
    length as *waypoints* but with U-turn waypoints replaced by branch point
    coordinates.  ``snapped_indices`` lists which indices were modified.
    """
    uturn_indices = _detect_uturn_waypoints(directions_result)
    if not uturn_indices:
        return list(waypoints), []

    new_waypoints = list(waypoints)
    snapped: list[int] = []

    for idx in uturn_indices:
        if idx >= len(new_waypoints):
            continue
        branch = _find_branch_point(directions_result, idx)
        if branch is not None:
            logger.info(
                "Snapped waypoint %d from (%.4f,%.4f) to branch point (%.4f,%.4f)",
                idx,
                waypoints[idx][0], waypoints[idx][1],
                branch[0], branch[1],
            )
            new_waypoints[idx] = branch
            snapped.append(idx)

    return new_waypoints, snapped


# ---------------------------------------------------------------------------
# Retry: extract route summary + fix waypoints
# ---------------------------------------------------------------------------


def _extract_route_summary(directions_result: dict[str, Any] | None) -> str:
    """Extracts a human-readable summary of the route from the Directions API.

    Pulls road names and cities from step instructions so Claude can see
    exactly where the route goes wrong (e.g. "Route passes through Amsterdam
    via A10 ring road").
    """
    if not directions_result:
        return ""

    lines: list[str] = []
    for leg_idx, leg in enumerate(directions_result.get("legs", [])):
        start = leg.get("start_address", "unknown")
        end = leg.get("end_address", "unknown")
        dist = leg.get("distance", {}).get("text", "?")
        lines.append(f"Leg {leg_idx + 1}: {start} → {end} ({dist})")

        # Extract key road names from step instructions.
        road_mentions: list[str] = []
        for step in leg.get("steps", []):
            instr = step.get("html_instructions", "")
            # Strip HTML tags for readability.
            clean = instr.replace("<b>", "").replace("</b>", "")
            clean = clean.replace("<div>", " | ").replace("</div>", "")
            clean = clean.replace("<wbr/>", "")
            if clean:
                road_mentions.append(clean)
        # Include up to 8 steps per leg to keep the summary manageable.
        for mention in road_mentions[:8]:
            lines.append(f"  - {mention}")
        if len(road_mentions) > 8:
            lines.append(f"  ... and {len(road_mentions) - 8} more steps")

    return "\n".join(lines)


_FIX_PROMPT = """\
The motorcycle route you generated has these validation issues:
{issues}

Original preferences:
- Distance: {distance_km} km
- Curviness: {curviness}/5
- Scenery: {scenery_type}
- Route type: {route_type}

Current waypoints:
{current_waypoints}

The Directions API routed through these roads and areas:
{route_summary}

Based on the ACTUAL ROADS the route used (shown above), adjust the waypoints \
to fix the issues:
- If the route passes through a city, move the nearby waypoints so the \
connecting road bypasses that city entirely.
- If the route uses highways/motorways, shift waypoints to force secondary \
road connections.
- If the route doubles back or has dead-end spurs, move the offending waypoint \
to a location that connects via through-roads.
- Use your knowledge of the region's actual road network.
- Keep the same waypoint count ({n_waypoints}).

Return ONLY a JSON array: [{{"lat": ..., "lng": ...}}, ...]
"""


async def _fix_waypoints(
    claude_client: AsyncAnthropic,
    current: list[tuple[float, float]],
    issues: list[str],
    prefs: RoutePreferences,
    *,
    route_summary: str = "",
) -> tuple[list[tuple[float, float]], str]:
    """Asks Claude to adjust waypoints using actual route feedback.

    Unlike the old approach which only told Claude about abstract issues,
    this version includes the actual road names and cities the route passed
    through so Claude can make informed geographic adjustments.

    Returns:
        Tuple of (waypoints, prompt_sent) for debug logging.
    """
    wp_str = "\n".join(
        f"  {i + 1}. lat={lat}, lng={lng}"
        for i, (lat, lng) in enumerate(current)
    )
    prompt = _FIX_PROMPT.format(
        issues="\n".join(f"- {issue}" for issue in issues),
        distance_km=prefs.distance_km,
        curviness=prefs.curviness,
        scenery_type=prefs.scenery_type,
        route_type="loop" if prefs.loop else "one-way",
        current_waypoints=wp_str,
        route_summary=route_summary or "(no route details available)",
        n_waypoints=len(current),
    )

    response = await claude_client.messages.create(
        model=ROUTE_MODEL,
        max_tokens=512,
        system=_JSON_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = response.content[0].text.strip()

    parsed = _extract_json_array(raw)
    if parsed is not None and len(parsed) == len(current):
        try:
            return [(float(p["lat"]), float(p["lng"])) for p in parsed], prompt
        except (KeyError, TypeError, ValueError):
            logger.warning("Fix JSON missing lat/lng keys: %s", raw[:200])

    logger.warning("Could not parse Claude fix response; keeping current waypoints")
    return current, prompt


# ---------------------------------------------------------------------------
# Step 8: Narrative generation
# ---------------------------------------------------------------------------

_NARRATIVE_PROMPT = """\
You are writing a route description for a motorcycle enthusiast app.

Route details:
- Distance: {distance_km:.1f} km
- Estimated duration: {duration_min} minutes
- Rider preferences: {distance_km:.0f}km, curviness {curviness}/5, {scenery_type} scenery, {route_type}
- Route overview: starts at {start}, passes through {n_waypoints} waypoints

Write 3–4 sentences describing this route. Be specific to the geography and
terrain where possible. Mention what makes this route worth riding — the
character of the roads, the scenery, notable features. Tone: direct,
enthusiastic, written for a rider who knows what a good road feels like.
No generic filler. No "you will love this route" language.
"""


async def _generate_narrative(
    claude_client: AsyncAnthropic,
    directions_result: dict[str, Any],
    prefs: RoutePreferences,
) -> tuple[str, str]:
    """Generates a route narrative using Claude Sonnet.

    Returns:
        Tuple of (narrative_text, prompt_sent) for debug logging.
    """
    distance_km, duration_min = _sum_legs(directions_result)
    start_address = directions_result["legs"][0].get(
        "start_address", prefs.start_location
    )
    n_waypoints = len(directions_result.get("key_waypoints", []))

    prompt = _NARRATIVE_PROMPT.format(
        distance_km=distance_km,
        duration_min=duration_min,
        curviness=prefs.curviness,
        scenery_type=prefs.scenery_type,
        route_type="loop" if prefs.loop else "one-way",
        start=start_address,
        n_waypoints=n_waypoints,
    )

    logger.info("Requesting route narrative from Claude")
    response = await claude_client.messages.create(
        model=ROUTE_MODEL,
        max_tokens=300,
        messages=[{"role": "user", "content": prompt}],
    )
    return response.content[0].text.strip(), prompt


# ---------------------------------------------------------------------------
# Step 9: Street View images
# ---------------------------------------------------------------------------


def _compute_road_heading(
    lat: float,
    lng: float,
    polyline_points: list[tuple[float, float]],
) -> float:
    """Computes the road bearing at the given point using the nearest polyline segment.

    Falls back to 0 (north) if no polyline is available.
    """
    if len(polyline_points) < 2:
        return 0.0

    # Find the nearest polyline point.
    best_idx = 0
    best_dist = float("inf")
    for i, (plat, plng) in enumerate(polyline_points):
        d = _haversine_m(lat, lng, plat, plng)
        if d < best_dist:
            best_dist = d
            best_idx = i

    # Use the bearing from this point to the next (or previous to this).
    if best_idx < len(polyline_points) - 1:
        p1 = polyline_points[best_idx]
        p2 = polyline_points[best_idx + 1]
    else:
        p1 = polyline_points[best_idx - 1]
        p2 = polyline_points[best_idx]

    return _bearing(p1[0], p1[1], p2[0], p2[1])


def _check_street_view_coverage(
    lat: float, lng: float, api_key: str
) -> tuple[bool, float, float]:
    """Checks if Street View coverage exists at the given coordinates.

    Uses the Street View Metadata API (free, no quota consumed).

    Returns:
        Tuple of (has_coverage, actual_lat, actual_lng).
        If coverage exists, actual_lat/actual_lng are the coordinates of
        the nearest panorama (may differ slightly from input).
    """
    try:
        resp = requests.get(
            f"{_STREETVIEW_BASE}/metadata",
            params={"location": f"{lat},{lng}", "key": api_key},
            timeout=5,
        )
        data = resp.json()
        if data.get("status") == "OK":
            loc = data.get("location", {})
            return (
                True,
                float(loc.get("lat", lat)),
                float(loc.get("lng", lng)),
            )
    except Exception:  # noqa: BLE001
        logger.warning("Street View metadata check failed for %.4f,%.4f", lat, lng)
    return (False, lat, lng)


def _find_street_view_along_route(
    lat: float,
    lng: float,
    polyline_points: list[tuple[float, float]],
    api_key: str,
) -> tuple[bool, float, float]:
    """Searches along the route polyline for the nearest point with Street View.

    Starting from the polyline point closest to (lat, lng), walks outward in
    both directions checking every STREET_VIEW_SEARCH_INTERVAL_M for coverage.
    """
    if not polyline_points:
        return (False, lat, lng)

    # Find the nearest polyline point.
    best_idx = 0
    best_dist = float("inf")
    for i, (plat, plng) in enumerate(polyline_points):
        d = _haversine_m(lat, lng, plat, plng)
        if d < best_dist:
            best_dist = d
            best_idx = i

    # Walk outward in both directions from best_idx.
    for direction in (1, -1):
        accumulated_m = 0.0
        idx = best_idx
        last_checked_m = 0.0
        while 0 <= idx < len(polyline_points) - 1:
            next_idx = idx + direction
            if not (0 <= next_idx < len(polyline_points)):
                break
            seg = _haversine_m(
                polyline_points[idx][0], polyline_points[idx][1],
                polyline_points[next_idx][0], polyline_points[next_idx][1],
            )
            accumulated_m += seg
            if accumulated_m > STREET_VIEW_SEARCH_RADIUS_M:
                break
            if accumulated_m - last_checked_m >= STREET_VIEW_SEARCH_INTERVAL_M:
                last_checked_m = accumulated_m
                plat, plng = polyline_points[next_idx]
                ok, sv_lat, sv_lng = _check_street_view_coverage(
                    plat, plng, api_key
                )
                if ok:
                    return (True, sv_lat, sv_lng)
            idx = next_idx

    return (False, lat, lng)


def _get_street_view_urls(
    waypoints: list[tuple[float, float]],
    api_key: str,
    overview_polyline: str = "",
) -> list[str]:
    """Returns Street View Static API URLs for waypoints with verified coverage.

    For each waypoint, checks the Street View Metadata API (free) to verify
    coverage exists. If not, searches along the route polyline for the nearest
    point with coverage. Only returns URLs for locations with confirmed coverage.
    """
    polyline_points = (
        _decode_polyline(overview_polyline) if overview_polyline else []
    )
    urls = []
    for lat, lng in waypoints[:STREET_VIEW_IMAGE_COUNT]:
        # Check coverage at the exact waypoint.
        has_coverage, sv_lat, sv_lng = _check_street_view_coverage(
            lat, lng, api_key
        )

        if not has_coverage and polyline_points:
            # Search along the route polyline for nearby coverage.
            has_coverage, sv_lat, sv_lng = _find_street_view_along_route(
                lat, lng, polyline_points, api_key
            )

        if not has_coverage:
            logger.warning(
                "No Street View coverage near waypoint %.4f,%.4f — skipping",
                lat, lng,
            )
            continue

        heading = _compute_road_heading(sv_lat, sv_lng, polyline_points)
        url = (
            f"{_STREETVIEW_BASE}"
            f"?size={STREET_VIEW_SIZE}"
            f"&location={sv_lat},{sv_lng}"
            f"&fov={STREET_VIEW_FOV}"
            f"&pitch={STREET_VIEW_PITCH}"
            f"&heading={heading:.0f}"
            f"&key={api_key}"
        )
        urls.append(url)
    return urls
