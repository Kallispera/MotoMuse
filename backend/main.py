"""MotoMuse Cloud Run backend service.

Exposes endpoints for motorcycle photo analysis and garage personality
generation, both powered by the GPT-5.2 two-phase pipeline.
"""

import logging

from fastapi import FastAPI, HTTPException

import bike_vision
from models import (
    AnalyzeBikeRequest,
    BikeAnalysisResponse,
    GaragePersonalityRequest,
    GaragePersonalityResponse,
)

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="MotoMuse Backend",
    description="AI-powered motorcycle identification and route generation.",
    version="0.2.0",
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
