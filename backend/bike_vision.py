"""Two-phase GPT-5.2 pipeline: vision extraction followed by rider insights.

Phase 1 — Vision extraction
  GPT-5.2 analyses the motorcycle photograph and returns a structured JSON
  object containing every identifiable detail: make, model, year, engine
  displacement, colour, trim, visible modifications, category, and any
  distinctive features unique to this bike or generation.

Phase 2 — Rider insights
  GPT-5.2 receives all extracted details and returns two pieces of copy:
    personality_line   — a single punchy line about what the bike says about
                         its rider (shown at the top of the review card).
    affirming_message  — 2–3 sentences of genuine facts about the specific
                         make/model: performance figures, race heritage,
                         engineering quirks, historical significance.
"""

import json
import logging
import os

from openai import AsyncOpenAI

from models import BikeAnalysisResponse

logger = logging.getLogger(__name__)

# The OpenAI model used for both vision extraction and message generation.
# Store as a constant so it can be updated in one place when the model
# identifier changes.
VISION_MODEL = "gpt-5.2"

_EXTRACTION_PROMPT = """\
You are an expert motorcycle identifier with encyclopaedic knowledge of every
make, model, trim, and generation produced worldwide.

Analyse the motorcycle in this photograph and extract every visible detail.

Return ONLY a valid JSON object — no markdown fences, no commentary — with
exactly these fields:

  make            string   Manufacturer name (e.g. "Ducati", "Honda", "BMW")
  model           string   Model name (e.g. "Panigale V4 S", "CBR600RR", "R 1250 GS")
  year            integer  Estimated manufacture year, or null if not determinable
  displacement    string   Engine size if readable from badging (e.g. "1103cc"), or null
  color           string   Precise colour description (e.g. "Ducati Red", "Matte Black")
  trim            string   Trim level or variant (e.g. "S", "SP", "Adventure"), or null
  modifications   array    Visible non-stock or aftermarket parts as strings
                           (e.g. ["Akrapovic titanium slip-on", "bar-end mirrors",
                           "carbon fibre belly pan"]). Empty array if stock.
  category        string   One of: sport | naked | cruiser | adventure | touring |
                           scrambler | cafe_racer | enduro | other
  distinctive_features  array  Specific interesting details about this exact bike or
                               generation — engineering quirks, racing heritage,
                               design notes, limited-edition status, etc.

Only include what you can actually see or confidently infer from visible details.
Be specific rather than generic. If unsure of a field, set it to null.\
"""

_MESSAGE_PROMPT = """\
You are writing copy for a motorcycle enthusiast app used predominantly by
male riders who know their bikes and will see through anything generic.

Here are the details extracted from their motorcycle photograph:
{details}

Return ONLY a valid JSON object with exactly these two fields:

  personality_line
    A single sentence, maximum 15 words, about what owning this specific bike
    says about its rider. Be direct and specific to this model's culture,
    reputation, or riding tribe — not flattery. Think what a knowledgeable
    mate would say at the pub. Examples of the right tone:
      "You bought the bike that terrified Japanese manufacturers when it launched."
      "This is what people who've already owned everything else end up on."
      "Adventure-spec equipment, weekend warrior mileage — the best kind of contradiction."
    No adjectives like "great", "amazing", or "excellent". No clichés.

  affirming_message
    Two to three sentences of genuinely interesting facts about this exact
    make and model. Real performance figures, race victories, engineering
    quirks unique to this generation, production numbers if notable, famous
    riders who campaigned it, or what made this model historically significant.
    Not a description of what is visible in the photo. Facts a proper
    enthusiast would actually find interesting.

Tone for both fields: Direct, informed, written for someone who already
knows bikes. No fluff.\
"""

_GARAGE_PROMPT = """\
You are writing copy for a motorcycle enthusiast app.

A rider has {count} bikes in their garage:
{bike_list}

Write a single sentence, maximum 20 words, about what this collection says
about them as a rider. Be specific to the actual combination — if the bikes
span different categories or eras, comment on the range; if they are all
from the same tribe, comment on the focus or obsession. Direct, no flattery.
Written for a predominantly male audience who will see through anything generic.\
"""


async def analyze(
    image_url: str,
    *,
    client: AsyncOpenAI | None = None,
) -> BikeAnalysisResponse:
    """Analyses a motorcycle image and returns details plus rider insights.

    Args:
        image_url: A publicly accessible URL to the motorcycle photograph.
        client: Optional pre-constructed ``AsyncOpenAI`` client. If omitted,
            one is created using the ``OPENAI_API_KEY`` environment variable.

    Returns:
        A ``BikeAnalysisResponse`` with all extracted fields, a personality
        one-liner, and interesting facts about the specific bike.

    Raises:
        ValueError: If ``OPENAI_API_KEY`` is not set and no client is provided.
        openai.OpenAIError: On any API-level failure.
    """
    _client = client or AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
    details = await _extract_details(_client, image_url)
    personality_line, affirming_message = await _generate_messages(_client, details)

    return BikeAnalysisResponse(
        make=details.get("make", "Unknown"),
        model=details.get("model", "Unknown"),
        year=details.get("year"),
        displacement=details.get("displacement"),
        color=details.get("color"),
        trim=details.get("trim"),
        modifications=details.get("modifications", []),
        category=details.get("category"),
        personality_line=personality_line,
        affirming_message=affirming_message,
    )


async def garage_personality(
    bikes: list[dict],
    *,
    client: AsyncOpenAI | None = None,
) -> str:
    """Generates a one-liner about what a rider's bike collection says about them.

    Args:
        bikes: List of dicts with at least ``make`` and ``model`` keys.
        client: Optional pre-constructed ``AsyncOpenAI`` client.

    Returns:
        A single sentence describing the rider's garage personality.
    """
    _client = client or AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])

    bike_list = "\n".join(
        f"- {b.get('year', '')} {b.get('make', '')} {b.get('model', '')}".strip()
        for b in bikes
    )
    prompt = _GARAGE_PROMPT.format(count=len(bikes), bike_list=bike_list)

    logger.info("Garage personality: generating for %d bikes", len(bikes))
    response = await _client.chat.completions.create(
        model=VISION_MODEL,
        messages=[{"role": "user", "content": prompt}],
        max_completion_tokens=64,
    )
    result = (response.choices[0].message.content or "").strip()
    logger.info("Garage personality complete — %d chars", len(result))
    return result


async def _extract_details(
    client: AsyncOpenAI,
    image_url: str,
) -> dict:
    """Calls GPT vision to extract structured motorcycle details as a dict."""
    logger.info("Phase 1: extracting bike details from image")

    response = await client.chat.completions.create(
        model=VISION_MODEL,
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": _EXTRACTION_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": image_url, "detail": "high"},
                    },
                ],
            },
        ],
        max_completion_tokens=1024,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or "{}"
    logger.info("Phase 1 complete — raw JSON length: %d", len(raw))

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.warning("Failed to parse vision response as JSON; using fallback")
        return {"make": "Unknown", "model": "Unknown"}


async def _generate_messages(
    client: AsyncOpenAI,
    details: dict,
) -> tuple[str, str]:
    """Generates personality_line and affirming_message for the bike.

    Returns:
        Tuple of (personality_line, affirming_message).
    """
    logger.info("Phase 2: generating rider insights")

    prompt = _MESSAGE_PROMPT.format(
        details=json.dumps(details, indent=2, ensure_ascii=False),
    )

    response = await client.chat.completions.create(
        model=VISION_MODEL,
        messages=[{"role": "user", "content": prompt}],
        max_completion_tokens=512,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or "{}"
    logger.info("Phase 2 complete — raw length: %d chars", len(raw))

    try:
        parsed = json.loads(raw)
        personality_line = parsed.get("personality_line", "").strip()
        affirming_message = parsed.get("affirming_message", "").strip()
        return personality_line, affirming_message
    except json.JSONDecodeError:
        logger.warning("Failed to parse message response as JSON")
        return "", ""
