"""MotoMuse Cloud Run backend service.

Exposes a single endpoint that analyses a motorcycle photograph using the
GPT-5.2 two-phase pipeline (vision extraction + affirming message generation)
and returns structured bike details to the Flutter client.
"""

import logging

from fastapi import FastAPI, HTTPException

import bike_vision
from models import AnalyzeBikeRequest, BikeAnalysisResponse

logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title="MotoMuse Backend",
    description="AI-powered motorcycle identification and route generation.",
    version="0.1.0",
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
    2. Message generation — a warm, knowledgeable message that makes the
       rider feel proud of their specific machine.

    Args:
        request: Contains ``image_url``, a publicly accessible URL to the
            motorcycle photograph (Firebase Storage token URL).

    Returns:
        Full ``BikeAnalysisResponse`` with all extracted fields and the
        affirming message.

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
