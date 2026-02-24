"""Two-phase GPT-5.2 pipeline: vision extraction followed by message generation.

Phase 1 — Vision extraction
  GPT-5.2 analyses the motorcycle photograph and returns a structured JSON
  object containing every identifiable detail: make, model, year, engine
  displacement, colour, trim, visible modifications, category, and any
  distinctive features unique to this bike or generation.

Phase 2 — Affirming message generation
  GPT-5.2 receives all extracted details and writes a short, warm, enthusiast-
  level message that makes the rider feel proud of their specific machine.
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
You are a passionate, deeply knowledgeable motorcycle enthusiast writing
directly to a fellow rider who has just added their bike to MotoMuse.

Here are the details extracted from their photo:
{details}

Write 2–3 sentences that:
- Address the rider directly and warmly
- Name something genuinely interesting or impressive about THIS specific
  motorcycle — its racing heritage, engineering innovation, cultural status,
  what makes this generation special, a famous characteristic, or a detail
  only a true enthusiast would appreciate
- Make them feel proud of and connected to their machine
- Show real, specific knowledge — avoid generic praise like "great bike!"
- Feel personal and enthusiastic, not promotional

Respond with only the message text. No greetings, no sign-offs.\
"""


async def analyze(
    image_url: str,
    *,
    client: AsyncOpenAI | None = None,
) -> BikeAnalysisResponse:
    """Analyses a motorcycle image and returns details plus an affirming message.

    Args:
        image_url: A publicly accessible URL to the motorcycle photograph.
        client: Optional pre-constructed ``AsyncOpenAI`` client. If omitted,
            one is created using the ``OPENAI_API_KEY`` environment variable.

    Returns:
        A ``BikeAnalysisResponse`` with all extracted fields and the generated
        affirming message.

    Raises:
        ValueError: If ``OPENAI_API_KEY`` is not set and no client is provided.
        openai.OpenAIError: On any API-level failure.
    """
    _client = client or AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])
    details = await _extract_details(_client, image_url)
    message = await _generate_message(_client, details)

    return BikeAnalysisResponse(
        make=details.get("make", "Unknown"),
        model=details.get("model", "Unknown"),
        year=details.get("year"),
        displacement=details.get("displacement"),
        color=details.get("color"),
        trim=details.get("trim"),
        modifications=details.get("modifications", []),
        category=details.get("category"),
        affirming_message=message,
    )


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
        max_tokens=1024,
        response_format={"type": "json_object"},
    )

    raw = response.choices[0].message.content or "{}"
    logger.info("Phase 1 complete — raw JSON length: %d", len(raw))

    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        logger.warning("Failed to parse vision response as JSON; using fallback")
        return {"make": "Unknown", "model": "Unknown"}


async def _generate_message(client: AsyncOpenAI, details: dict) -> str:
    """Calls GPT to write an affirming, enthusiast-level message about the bike."""
    logger.info("Phase 2: generating affirming message")

    prompt = _MESSAGE_PROMPT.format(
        details=json.dumps(details, indent=2, ensure_ascii=False),
    )

    response = await client.chat.completions.create(
        model=VISION_MODEL,
        messages=[{"role": "user", "content": prompt}],
        max_tokens=256,
    )

    message = (response.choices[0].message.content or "").strip()
    logger.info("Phase 2 complete — message length: %d chars", len(message))
    return message
