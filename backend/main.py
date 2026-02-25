"""MotoMuse Cloud Run backend service.

Exposes endpoints for motorcycle photo analysis, garage personality
generation, route generation, address geocoding, and home affirming messages.
"""

import logging
import os

from anthropic import AsyncAnthropic
from fastapi import FastAPI, HTTPException

import googlemaps

import bike_vision
import route_generation
from models import (
    AnalyzeBikeRequest,
    BikeAnalysisResponse,
    GaragePersonalityRequest,
    GaragePersonalityResponse,
    GeocodeRequest,
    GeocodeResponse,
    HomeAffirmingRequest,
    HomeAffirmingResponse,
    RoutePreferences,
    RouteResult,
)

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="MotoMuse Backend",
    description="AI-powered motorcycle identification and route generation.",
    version="0.3.0",
)


@app.get("/health")
async def health() -> dict[str, str]:
    """Health check endpoint used by Cloud Run to verify the service is live."""
    return {"status": "ok"}


@app.post("/analyze-bike", response_model=BikeAnalysisResponse)
async def analyze_bike(request: AnalyzeBikeRequest) -> BikeAnalysisResponse:
    """Identifies a motorcycle from a photo URL.

    Runs a two-phase GPT-5.2 pipeline:
    1. Vision extraction — structured JSON of make, model, year, specs,
       modifications, and distinctive features.
    2. Rider insights — a personality one-liner and interesting facts about
       the specific make/model.

    Args:
        request: Contains ``image_url``, a publicly accessible URL to the
            motorcycle photograph (Firebase Storage token URL).

    Returns:
        Full ``BikeAnalysisResponse`` with all extracted fields, personality
        line, and affirming message.

    Raises:
        HTTPException 502: If the upstream OpenAI API call fails.
    """
    try:
        return await bike_vision.analyze(request.image_url)
    except Exception as exc:  # noqa: BLE001
        logging.exception("bike_vision.analyze failed")
        raise HTTPException(
            status_code=502,
            detail="Failed to analyse the bike photo. Please try again.",
        ) from exc


@app.post("/garage-personality", response_model=GaragePersonalityResponse)
async def garage_personality(
    request: GaragePersonalityRequest,
) -> GaragePersonalityResponse:
    """Generates a one-liner about what a rider's bike collection says about them.

    Requires at least two bikes. Returns a single sentence specific to the
    combination of bikes in the garage.

    Args:
        request: Contains ``bikes``, a list of dicts with make, model, year,
            and category fields.

    Returns:
        ``GaragePersonalityResponse`` with a single ``personality`` string.

    Raises:
        HTTPException 400: If fewer than two bikes are provided.
        HTTPException 502: If the upstream OpenAI API call fails.
    """
    if len(request.bikes) < 2:
        raise HTTPException(
            status_code=400,
            detail="At least two bikes are required to generate a garage personality.",
        )
    try:
        text = await bike_vision.garage_personality(request.bikes)
        return GaragePersonalityResponse(personality=text)
    except Exception as exc:  # noqa: BLE001
        logging.exception("garage_personality failed")
        raise HTTPException(
            status_code=502,
            detail="Failed to generate garage personality. Please try again.",
        ) from exc


@app.post("/generate-route", response_model=RouteResult)
async def generate_route(request: RoutePreferences) -> RouteResult:
    """Generates a high-quality motorcycle route matching the rider's preferences.

    Runs a nine-step pipeline:
    1. Geocodes the start location.
    2. Generates geometric candidate waypoints.
    3. Fetches elevation data for each candidate.
    4. Scores scenery proximity via the Places API.
    5. Claude Sonnet selects and orders the best waypoints.
    6. Google Directions API builds the navigable route (avoids highways).
    7. Validates the route polyline; retries up to 3× if issues are found.
    8. Claude Sonnet generates a narrative description.
    9. Street View Static API fetches 2–3 scenic images.

    Args:
        request: ``RoutePreferences`` with start location, distance, curviness,
            scenery type, and loop/one-way preference.

    Returns:
        ``RouteResult`` with encoded polyline, stats, waypoints, narrative,
        and Street View image URLs.

    Raises:
        HTTPException 400: If start_location is empty.
        HTTPException 502: If the upstream API calls fail.
    """
    if not request.start_location.strip():
        raise HTTPException(
            status_code=400,
            detail="start_location must not be empty.",
        )
    try:
        return await route_generation.generate(request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        logging.exception("route_generation.generate failed")
        raise HTTPException(
            status_code=502,
            detail="Failed to generate a route. Please try again.",
        ) from exc


@app.post("/geocode-address", response_model=GeocodeResponse)
async def geocode_address(request: GeocodeRequest) -> GeocodeResponse:
    """Geocodes a human-readable address to lat/lng coordinates.

    Uses the Google Maps Geocoding API to resolve the address.

    Args:
        request: Contains ``address``, the address string to geocode.

    Returns:
        ``GeocodeResponse`` with lat, lng, and the Google-formatted address.

    Raises:
        HTTPException 400: If address is empty.
        HTTPException 404: If the address could not be geocoded.
        HTTPException 502: If the upstream Google Maps API call fails.
    """
    if not request.address.strip():
        raise HTTPException(
            status_code=400,
            detail="address must not be empty.",
        )
    try:
        gmaps = googlemaps.Client(
            key=os.environ.get("GOOGLE_MAPS_API_KEY", ""),
        )
        result = gmaps.geocode(request.address)
        if not result:
            raise HTTPException(
                status_code=404,
                detail=f"Could not geocode address: {request.address!r}",
            )
        location = result[0]["geometry"]["location"]
        formatted = result[0].get("formatted_address", request.address)
        return GeocodeResponse(
            lat=float(location["lat"]),
            lng=float(location["lng"]),
            formatted_address=formatted,
        )
    except HTTPException:
        raise
    except Exception as exc:  # noqa: BLE001
        logging.exception("geocode_address failed")
        raise HTTPException(
            status_code=502,
            detail="Failed to geocode the address. Please try again.",
        ) from exc


@app.post("/home-affirming-message", response_model=HomeAffirmingResponse)
async def home_affirming_message(
    request: HomeAffirmingRequest,
) -> HomeAffirmingResponse:
    """Generates a warm, affirming message about living near a great riding area.

    Uses Claude Haiku to produce a short 2-3 sentence message telling the
    rider how lucky they are to live close to the specified riding region.

    Args:
        request: Contains ``address`` (the rider's home address) and
            ``closest_region`` (name of the nearest riding area).

    Returns:
        ``HomeAffirmingResponse`` with the generated ``message``.

    Raises:
        HTTPException 400: If address or closest_region is empty.
        HTTPException 502: If the upstream Anthropic API call fails.
    """
    if not request.address.strip():
        raise HTTPException(
            status_code=400,
            detail="address must not be empty.",
        )
    if not request.closest_region.strip():
        raise HTTPException(
            status_code=400,
            detail="closest_region must not be empty.",
        )
    try:
        anthropic_client = AsyncAnthropic(
            api_key=os.environ.get("ANTHROPIC_API_KEY", ""),
        )
        response = await anthropic_client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=256,
            messages=[
                {
                    "role": "user",
                    "content": (
                        f"The rider lives at {request.address} and the closest "
                        f"great motorcycle riding area is {request.closest_region}. "
                        "Write a warm, affirming 2-3 sentence message about how "
                        "lucky they are to live so close to such a wonderful "
                        "riding area. Be specific about the region. Do not use "
                        "any markdown formatting."
                    ),
                },
            ],
        )
        message_text = response.content[0].text
        return HomeAffirmingResponse(message=message_text)
    except Exception as exc:  # noqa: BLE001
        logging.exception("home_affirming_message failed")
        raise HTTPException(
            status_code=502,
            detail="Failed to generate affirming message. Please try again.",
        ) from exc
