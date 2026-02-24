"""Unit tests for bike_vision.py.

All OpenAI API calls are replaced with mocks so tests run offline and cheaply.
"""

import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

import bike_vision
from models import BikeAnalysisResponse


# ---------------------------------------------------------------------------
# Helpers — build a fake OpenAI response object
# ---------------------------------------------------------------------------


def _make_completion(content: str) -> MagicMock:
    """Returns a minimal fake ChatCompletion object with the given content."""
    message = SimpleNamespace(content=content)
    choice = SimpleNamespace(message=message)
    return SimpleNamespace(choices=[choice])


def _make_client(
    extraction_json: dict | None = None,
    message_text: str = "What a magnificent machine you have there!",
) -> AsyncMock:
    """Creates a mock AsyncOpenAI client with pre-configured responses.

    The first ``create`` call returns the vision extraction JSON;
    the second returns the affirming message text.
    """
    extraction_payload = extraction_json or {
        "make": "Ducati",
        "model": "Panigale V4 S",
        "year": 2023,
        "displacement": "1103cc",
        "color": "Ducati Red",
        "trim": "S",
        "modifications": ["Akrapovic titanium exhaust"],
        "category": "sport",
        "distinctive_features": ["Desmosedici Stradale engine from MotoGP"],
    }

    client = MagicMock()
    client.chat = MagicMock()
    client.chat.completions = MagicMock()
    client.chat.completions.create = AsyncMock(
        side_effect=[
            _make_completion(json.dumps(extraction_payload)),
            _make_completion(message_text),
        ]
    )
    return client


# ---------------------------------------------------------------------------
# analyze()
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_analyze_returns_full_response():
    """analyze() combines extraction and message into a BikeAnalysisResponse."""
    client = _make_client(
        message_text="The Panigale V4 S is poetry in aluminium.",
    )

    result = await bike_vision.analyze(
        "https://example.com/bike.jpg",
        client=client,
    )

    assert isinstance(result, BikeAnalysisResponse)
    assert result.make == "Ducati"
    assert result.model == "Panigale V4 S"
    assert result.year == 2023
    assert result.displacement == "1103cc"
    assert result.color == "Ducati Red"
    assert result.trim == "S"
    assert result.modifications == ["Akrapovic titanium exhaust"]
    assert result.category == "sport"
    assert result.affirming_message == "The Panigale V4 S is poetry in aluminium."


@pytest.mark.asyncio
async def test_analyze_calls_openai_twice():
    """analyze() makes exactly two API calls: one for vision, one for message."""
    client = _make_client()
    await bike_vision.analyze("https://example.com/bike.jpg", client=client)
    assert client.chat.completions.create.call_count == 2


@pytest.mark.asyncio
async def test_analyze_passes_image_url_to_first_call():
    """The image URL is included in the vision extraction request."""
    image_url = "https://storage.example.com/bikes/uid/photo.jpg"
    client = _make_client()

    await bike_vision.analyze(image_url, client=client)

    first_call_kwargs = client.chat.completions.create.call_args_list[0].kwargs
    messages = first_call_kwargs["messages"]
    content_parts = messages[0]["content"]
    image_part = next(p for p in content_parts if p.get("type") == "image_url")
    assert image_part["image_url"]["url"] == image_url


@pytest.mark.asyncio
async def test_analyze_uses_correct_model():
    """Both API calls use the VISION_MODEL constant."""
    client = _make_client()
    await bike_vision.analyze("https://example.com/bike.jpg", client=client)

    for call in client.chat.completions.create.call_args_list:
        assert call.kwargs["model"] == bike_vision.VISION_MODEL


@pytest.mark.asyncio
async def test_analyze_handles_null_optional_fields():
    """analyze() copes with null optional fields from the vision response."""
    client = _make_client(
        extraction_json={
            "make": "Honda",
            "model": "CB500F",
            "year": None,
            "displacement": None,
            "color": "Matte Black",
            "trim": None,
            "modifications": [],
            "category": "naked",
            "distinctive_features": [],
        },
    )

    result = await bike_vision.analyze("https://example.com/bike.jpg", client=client)

    assert result.make == "Honda"
    assert result.model == "CB500F"
    assert result.year is None
    assert result.displacement is None
    assert result.trim is None
    assert result.modifications == []


@pytest.mark.asyncio
async def test_analyze_recovers_from_malformed_extraction_json():
    """analyze() falls back to Unknown make/model if vision returns bad JSON."""
    client = MagicMock()
    client.chat = MagicMock()
    client.chat.completions = MagicMock()
    client.chat.completions.create = AsyncMock(
        side_effect=[
            _make_completion("This is not valid JSON {{{"),
            _make_completion("A unique bike."),
        ]
    )

    result = await bike_vision.analyze("https://example.com/bike.jpg", client=client)

    assert result.make == "Unknown"
    assert result.model == "Unknown"
    assert result.affirming_message == "A unique bike."


@pytest.mark.asyncio
async def test_analyze_strips_whitespace_from_message():
    """The affirming message is stripped of leading/trailing whitespace."""
    client = _make_client(message_text="  Great bike!  \n")
    result = await bike_vision.analyze("https://example.com/bike.jpg", client=client)
    assert result.affirming_message == "Great bike!"


# ---------------------------------------------------------------------------
# VISION_MODEL constant
# ---------------------------------------------------------------------------


def test_vision_model_constant_is_set():
    """VISION_MODEL is a non-empty string."""
    assert isinstance(bike_vision.VISION_MODEL, str)
    assert len(bike_vision.VISION_MODEL) > 0
