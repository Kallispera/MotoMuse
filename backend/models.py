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
