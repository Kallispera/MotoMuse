# MotoMuse Route Generation Rules

All tuneable constants live at the top of `route_generation.py` under the
**Route-generation rules** block. Change a value there and redeploy — no other
code needs touching.

---

## Step 1 — Candidate waypoints

Before Claude gets involved, the pipeline generates a spread of geographic
candidates based purely on geometry.

| Constant | Default | What it does |
|---|---|---|
| `LOOP_CANDIDATE_COUNT` | `6` | Points placed evenly around a circle for a loop route. More points = Claude has more to choose from, but also more Places API calls in step 4. |
| `ONEWAY_CANDIDATE_COUNT` | `4` | Points spread along a forward arc for a one-way route. |
| `WAYPOINT_JITTER` | `0.20` | Each point's radius is multiplied by a random factor in the range `[1 - jitter, 1 + jitter]`. At 0.20, that's ±20%. Keeps the route from looking like a perfect hexagon. Increase toward 0.40 for wilder shapes; decrease toward 0.05 for tighter control. |

**Radius sizing:** For a loop, the circle radius is `distance_km / (2π)` so
that one full circuit approximates the requested distance. For one-way, each
waypoint is projected one quarter of the total distance further along a
bearing, spread across a 60° arc.

---

## Steps 2–3 — Elevation & scenery scoring

Each candidate gets two scores:

- **Elevation** — fetched from the Google Elevation API. Passed to Claude as
  context; not used to filter candidates directly.

- **Scenery** — how many relevant natural places are within
  `SCENERY_SEARCH_RADIUS_M` metres.

| Constant | Default | What it does |
|---|---|---|
| `SCENERY_SEARCH_RADIUS_M` | `5000` | Radius of the Places API nearby search in metres. Larger = picks up more distant features but may include irrelevant ones. |
| `SCENERY_KEYWORDS_USED` | `2` | How many keywords from the list below are searched per candidate. Each keyword = one Places API call. Keep low to control cost. |
| `SCENERY_SATURATION` | `5` | Number of matching places that maps to a perfect scenery score of 1.0. A candidate with 3 matches scores 0.6. |

**Keywords per scenery type** (defined in `_SCENERY_KEYWORDS` dict):

| Rider preference | Keywords searched |
|---|---|
| Forests | forest, woodland, nature reserve, national park |
| Coastline | beach, coast, harbour, cliff, sea |
| Mountains | mountain, peak, pass, ridge, fell |
| Mixed | park, forest, lake, river, nature |

To add a new scenery type, add an entry to `_SCENERY_KEYWORDS` in
`route_generation.py` *and* add the same string to the `sceneryType` options
in the Flutter `_ScenerySelector` widget.

---

## Step 4 — Claude waypoint selection

Claude receives all candidates with their elevation and scenery scores, then
picks and orders the best ones. The selection prompt is in the
`_WAYPOINT_SELECTION_PROMPT` constant in `route_generation.py`.

| Constant | Default | What it does |
|---|---|---|
| `LOOP_WAYPOINT_SELECT` | `4` | How many waypoints Claude picks for a loop. More = more complex route, more Directions API cost. |
| `ONEWAY_WAYPOINT_SELECT` | `3` | How many waypoints Claude picks for a one-way. |

**Prompt rules Claude follows (edit `_WAYPOINT_SELECTION_PROMPT` to change):**

- When curviness is low → favour high scenery scores
- When curviness is high → favour varied elevation (twisty terrain)
- Waypoints must form a coherent geographic path, not random jumps
- For a loop, the last waypoint should arc back toward the start

---

## Steps 5–6 — Directions API & validation

The Directions API builds the actual navigable route through the selected
waypoints. It is configured to `avoid = ["highways", "tolls"]` — this is
hardcoded, not a constant, because it's a hard product requirement.

The resulting route is then validated. If it fails, Claude is asked to adjust
the waypoints and the Directions call is retried.

| Constant | Default | What it does |
|---|---|---|
| `MAX_ROUTE_ATTEMPTS` | `3` | How many times the validate → fix → retry loop runs before accepting whatever we have. Higher = better quality but more latency and API cost. |
| `HIGHWAY_FRACTION_LIMIT` | `0.10` | Fail the route if more than this fraction of the total distance uses motorway-type roads. 0.10 = 10%. Lower = stricter. |
| `HIGHWAY_STEP_KEYWORDS` | see below | Instruction text keywords that identify a motorway step. Add road names here if specific local motorways keep slipping through (e.g. add `"a1"` if the A1 trunk road is a problem in your area). |
| `UTURN_STEP_MAX_M` | `200` | Both consecutive steps must be shorter than this for a U-turn to be flagged. Prevents false positives on long straight roads. |
| `UTURN_BEARING_CHANGE` | `150` | Bearing change in degrees that counts as a U-turn. 180° is a perfect reversal; 150° catches near-U-turns too. Reduce to ~130 for stricter detection. |

**Current `HIGHWAY_STEP_KEYWORDS`:**
`motorway`, `highway`, `freeway`, `m1`, `m20`, `m25`

---

## Step 7 — Narrative

Claude writes a 3–4 sentence route description. The prompt is in
`_NARRATIVE_PROMPT` in `route_generation.py`. Edit the prompt to change the
tone, length, or what Claude focuses on.

**Model used:** `ROUTE_MODEL` (default: `claude-sonnet-4-6`) — shared for both
waypoint selection and narrative. Change to `claude-haiku-4-5-20251001` to
reduce cost and latency at the expense of quality.

---

## Step 8 — Street View images

Three static Street View images are fetched at key points along the route
(first step, midpoint, last step) and shown on the route preview screen.

| Constant | Default | What it does |
|---|---|---|
| `STREET_VIEW_IMAGE_COUNT` | `3` | Maximum images fetched and shown. |
| `STREET_VIEW_SIZE` | `"400x240"` | Pixel dimensions. Must be a string in `WxH` format. |
| `STREET_VIEW_FOV` | `90` | Horizontal field of view in degrees. Lower = more zoomed in. |
| `STREET_VIEW_PITCH` | `10` | Camera tilt above the horizon in degrees. 0 = level, 10 = slightly upward (shows more sky and scenery). |

---

## Quality levers — quick reference

| Want to… | Change |
|---|---|
| More adventurous / random routes | Increase `WAYPOINT_JITTER` |
| Stricter about avoiding motorways | Lower `HIGHWAY_FRACTION_LIMIT`, add keywords to `HIGHWAY_STEP_KEYWORDS` |
| Faster generation (less cost) | Lower `LOOP_CANDIDATE_COUNT` / `ONEWAY_CANDIDATE_COUNT`, lower `MAX_ROUTE_ATTEMPTS`, lower `SCENERY_KEYWORDS_USED` |
| Better scenery matching | Increase `SCENERY_SEARCH_RADIUS_M`, increase `SCENERY_KEYWORDS_USED` |
| More waypoints per route | Increase `LOOP_WAYPOINT_SELECT` / `ONEWAY_WAYPOINT_SELECT` |
| Different narrative style | Edit `_NARRATIVE_PROMPT` in `route_generation.py` |
| Add a new scenery type | Add entry to `_SCENERY_KEYWORDS` dict + Flutter `_ScenerySelector` |
