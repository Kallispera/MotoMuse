"""Pydantic request and response models for the MotoMuse backend."""

from pydantic import BaseModel, HttpUrl


class AnalyzeBikeRequest(BaseModel):
    """Request body for the /analyze-bike endpoint."""

    image_url: str


class BikeAnalysisResponse(BaseModel):
    """Full response returned after analysing a motorcycle image.

    Contains structured identification data extracted by GPT vision, plus an
    LLM-generated message celebrating the rider's specific machine.
    """

    make: str
    model: str
    year: int | None = None
    displacement: str | None = None
    color: str | None = None
    trim: str | None = None
    modifications: list[str] = []
    category: str | None = None
    affirming_message: str
