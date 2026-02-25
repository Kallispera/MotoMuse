# MotoMuse Route Generation Rules

All tuneable constants live at the top of `route_generation.py` under the
**Route-generation rules** block. Change a value there and redeploy — no other
code needs touching.

---

## Step 1 — Geocoding & region context

The start location is geocoded, then **reverse-geocoded** to get a human-readable
region name (e.g. "Almere, Flevoland, Netherlands"). This region name is passed
to Claude so it can reason about local geography — water bodies, cities, road
networks — when generating waypoints.

---

## Step 2 — Claude-based waypoint generation

Claude generates waypoints directly using its geographic knowledge. This
replaces the old geometric candidate approach (which placed points on a circle
that could land in water or cities).

| Constant | Default | What it does |
|---|---|---|
| `LOOP_WAYPOINT_COUNT` | `5` | How many waypoints Claude generates for a loop route. |
| `ONEWAY_WAYPOINT_COUNT` | `4` | How many waypoints Claude generates for a one-way route. |

**Key prompt rules Claude follows (edit `_WAYPOINT_GENERATION_PROMPT` to change):**

- Every waypoint must be on or within 100m of a real, paved road
- Never place a waypoint in water (lakes, seas, rivers, reservoirs)
- Never place a waypoint in a city centre (pop > 50k)
- Consecutive waypoints must be connectable via rural roads without crossing
  water or passing through major cities
- For loops, the circuit should flow naturally back to the start
- Think about actual geography of the region: water bodies, mountains, forests
- Prefer scenic motorcycle-friendly roads (mountain passes, dyke roads, etc.)
- Think about the route *between* waypoints, not just the waypoints themselves
- Never place a waypoint at a dead-end road, cul-de-sac, or road with only
  one way in/out — every waypoint must be on a through-road

---

## Steps 3–4 — Directions API & validation

The Directions API builds the actual navigable route through the selected
waypoints. It is configured to `avoid = ["highways", "tolls"]` — this is
hardcoded, not a constant, because it's a hard product requirement.

The resulting route is then validated. If it fails, the retry mechanism kicks in:

- **Attempts 1–2:** Claude receives the actual route details (road names, cities,
  step instructions) and adjusts the waypoints to avoid problem areas.
- **Attempts 3–5:** Claude generates completely new waypoints with the failed
  route as negative context ("avoid these roads/areas").

| Constant | Default | What it does |
|---|---|---|
| `MAX_ROUTE_ATTEMPTS` | `5` | Total validation attempts before accepting whatever we have. |
| `FRESH_REGEN_ATTEMPT` | `3` | On this attempt and beyond, Claude generates entirely new waypoints instead of adjusting existing ones. |
| `HIGHWAY_FRACTION_LIMIT` | `0.10` | Fail the route if more than this fraction of the total distance uses motorway-type roads. 0.10 = 10%. |
| `HIGHWAY_STEP_KEYWORDS` | see below | Instruction text keywords that identify a motorway step. |
| `UTURN_STEP_MAX_M` | `200` | Both consecutive steps must be shorter than this for a U-turn to be flagged. |
| `UTURN_BEARING_CHANGE` | `150` | Bearing change in degrees that counts as a U-turn. |

**Current `HIGHWAY_STEP_KEYWORDS`:**
`motorway`, `highway`, `freeway`, `m1`, `m20`, `m25`, `a1`, `a2`, `a4`, `a6`, `a7`, `a9`, `a10`, `a27`, `a28`

**Polyline overlap detection (large-scale double-backs):** The validator decodes
the overview polyline, samples points at regular intervals, and flags routes
where too many non-adjacent samples are geographically close.

| Constant | Default | What it does |
|---|---|---|
| `OVERLAP_SAMPLE_INTERVAL_M` | `300` | Distance between sampled polyline points in metres. |
| `OVERLAP_PROXIMITY_THRESHOLD_M` | `150` | Two sampled points closer than this are considered overlapping. |
| `OVERLAP_MIN_INDEX_GAP` | `5` | Minimum index distance between samples before they count as "non-adjacent". |
| `OVERLAP_FRACTION_LIMIT` | `0.03` | Fail if more than 3% of sampled points overlap. |

**Dead-end spur detection:** The validator detects segments where the route
goes out along a road and comes back along the same corridor (dead-end spurs).
It samples the polyline, finds non-adjacent points that are geographically
close, then checks if the path distance between them is disproportionately
long compared to the straight-line distance.

| Constant | Default | What it does |
|---|---|---|
| `SPUR_SAMPLE_INTERVAL_M` | `200` | Distance between sampled polyline points in metres. |
| `SPUR_PROXIMITY_M` | `300` | Two sampled points closer than this may be spur endpoints. |
| `SPUR_MIN_INDEX_GAP` | `8` | Minimum samples apart to count as "non-adjacent". |
| `SPUR_PATH_RATIO` | `5.0` | path_distance / straight_distance threshold for flagging. |
| `SPUR_MIN_LENGTH_M` | `500` | Ignore spurs shorter than this. |

**Waypoint spur snapping:** Before validation runs, the pipeline checks each
waypoint for U-turns. If the route approaches a waypoint from one direction and
departs in roughly the opposite direction (bearing difference > 140°), the
waypoint is on a dead-end road. The algorithm then walks outward along the
incoming and outgoing legs simultaneously to find the "branch point" — where the
spur diverges from the main route. The waypoint is snapped to the branch point
and directions are re-requested. This is a geometric fix (no Claude call) and
happens transparently inside `_build_and_validate`.

| Constant | Default | What it does |
|---|---|---|
| `UTURN_BEARING_THRESHOLD` | `140` | Bearing difference (°) between approach and departure that flags a U-turn at a waypoint. |
| `SPUR_CORRIDOR_WIDTH_M` | `500` | Max distance (m) between approach/departure paths to be considered the same spur corridor. |
| `SPUR_SNAP_MIN_LENGTH_M` | `200` | Ignore spurs shorter than this for snapping (not worth the re-request). |

**Urban density detection:** Routes through cities produce many short steps with
frequent turns. The validator counts steps shorter than a threshold.

| Constant | Default | What it does |
|---|---|---|
| `URBAN_SHORT_STEP_THRESHOLD_M` | `300` | Steps shorter than this are classified as "urban-style". |
| `URBAN_SHORT_STEP_FRACTION_LIMIT` | `0.30` | Fail if more than 30% of steps are urban-style. |

**Route summary feedback:** When a route fails validation, `_extract_route_summary`
pulls road names and city names from the Directions API step instructions. This
summary is included in the retry prompt so Claude can see exactly where the
route went wrong (e.g. "Route passes through Amsterdam via A10 ring road").

---

## Step 5 — Narrative

Claude writes a 3–4 sentence route description. The prompt is in
`_NARRATIVE_PROMPT` in `route_generation.py`. Edit the prompt to change the
tone, length, or what Claude focuses on.

**Model used:** `ROUTE_MODEL` (default: `claude-sonnet-4-6`) — shared for
waypoint generation, retry fixes, and narrative. Change to
`claude-haiku-4-5-20251001` to reduce cost/latency at the expense of quality.

---

## Step 6 — Street View images

Up to three Street View images are shown on the route preview screen. Before
generating a URL, the backend checks the **Street View Metadata API** (free,
no quota consumed) to verify coverage exists at each waypoint. If no coverage
is found, it searches along the route polyline for the nearest point with
coverage. Only URLs with confirmed coverage are returned.

A `heading` parameter is computed from the route polyline bearing at each point
so the camera faces along the road direction.

| Constant | Default | What it does |
|---|---|---|
| `STREET_VIEW_IMAGE_COUNT` | `3` | Maximum images fetched and shown. |
| `STREET_VIEW_SIZE` | `"400x240"` | Pixel dimensions. Must be a string in `WxH` format. |
| `STREET_VIEW_FOV` | `90` | Horizontal field of view in degrees. |
| `STREET_VIEW_PITCH` | `10` | Camera tilt above the horizon in degrees. |
| `STREET_VIEW_SEARCH_RADIUS_M` | `2000` | Max distance to search along the route for Street View coverage. |
| `STREET_VIEW_SEARCH_INTERVAL_M` | `500` | Check every 500m along the route for coverage. |

---

## Debug output

Every `RouteResult` response includes a `debug` field with comprehensive
generation diagnostics. This is invaluable for troubleshooting route quality.

**Fields in `debug`:**

| Field | Type | What it contains |
|---|---|---|
| `attempts` | `int` | Total validation attempts made. |
| `passed_validation` | `bool` | Whether the final route passed all checks. |
| `original_waypoints` | `[{lat, lng}]` | Waypoints from the first Claude generation call. |
| `final_waypoints` | `[{lat, lng}]` | Waypoints used for the final route (after fixes/retries). |
| `snapped_waypoints` | `[{index, from, to}]` | Waypoints moved by the spur snapping algorithm. |
| `validation_history` | `[{attempt, issues, route_summary, waypoints, prompt_type, prompt_sent}]` | Per-attempt record of issues found, the route summary, and the fix/regen prompt sent to Claude. |
| `route_summary` | `string` | Final route summary (road names, cities, distances). |
| `waypoint_generation_prompt` | `string` | The full prompt sent to Claude for initial waypoint generation. |
| `narrative_prompt` | `string` | The full prompt sent to Claude for narrative generation. |
| `fix_prompts` | `[string]` | All fix/regeneration prompts sent to Claude during retries. |

---

## Quality levers — quick reference

| Want to… | Change |
|---|---|
| Stricter about avoiding motorways | Lower `HIGHWAY_FRACTION_LIMIT`, add keywords to `HIGHWAY_STEP_KEYWORDS` |
| Faster generation (less cost) | Lower `MAX_ROUTE_ATTEMPTS`, lower waypoint counts |
| More waypoints per route | Increase `LOOP_WAYPOINT_COUNT` / `ONEWAY_WAYPOINT_COUNT` |
| Stricter about double-backs | Lower `OVERLAP_FRACTION_LIMIT`, lower `OVERLAP_PROXIMITY_THRESHOLD_M` |
| Stricter about dead-end spurs | Lower `SPUR_MIN_LENGTH_M`, lower `SPUR_PATH_RATIO`, lower `UTURN_BEARING_THRESHOLD` |
| Stricter about urban routing | Lower `URBAN_SHORT_STEP_FRACTION_LIMIT`, lower `URBAN_SHORT_STEP_THRESHOLD_M` |
| Different narrative style | Edit `_NARRATIVE_PROMPT` in `route_generation.py` |
| Change waypoint generation rules | Edit `_WAYPOINT_GENERATION_PROMPT` in `route_generation.py` |
| Change retry feedback rules | Edit `_FIX_PROMPT` in `route_generation.py` |
