MotoMuse: Project Design Document

1. Executive Summary
MotoMuse is an AI-native motorcycle navigation app that prioritizes the "joy of the ride" (curves, scenery, and elevation) over the efficiency of the destination. It uses LLMs to curate routes, recognize motorcycles through computer vision, and provide real-time cultural "voiceovers" during the ride.

2. Business & Success Criteria
The "North Star" Metric: Number of "Curvy Kilometers" ridden by users.
MVP Success:
  * Zero-friction onboarding (Photo -> Bike Profile in < 60s).
  * High-quality route generation (Zero U-turns or highway-only routes).
  * 30% Spotify integration adoption.


3. System Design Principles

Code Health & Testing Strategy:
  Testing runs in CI on every pull request via GitHub Actions. Coverage is enforced automatically — a PR that drops below threshold cannot be merged.

  Test layers and coverage thresholds (line coverage):
    - Business logic / domain layer: 85% minimum
    - Data layer / repositories: 80% minimum
    - UI widgets / presentation layer: 60% minimum
    - Generated files (*.g.dart, *.freezed.dart): excluded entirely
    - Overall project floor: 75% minimum

  Tooling:
    - `flutter test --coverage` generates lcov.info on every CI run
    - `VeryGoodOpenSource/very_good_coverage@v2` GitHub Action enforces thresholds and fails the build if breached
    - `codecov/codecov-action@v3` uploads results to Codecov for trend reporting and PR annotations (free for teams up to 5 users on private repos)
    - Linting via `very_good_analysis` (188 rules, stricter than the default flutter_lints). Zero tolerance for analyser errors; warnings are reviewed before merge.
    - `flutter analyze` runs on every CI build; errors are a hard block on merge

  Test types expected per layer:
    - Unit tests: all business logic, route scoring algorithms, validation rules, LLM prompt builders
    - Widget tests: key UI screens (Garage, Scout, Route Preview, Ride)
    - Integration tests: critical user flows end-to-end (onboarding, route generation, navigation start)

  Mutation testing (post-MVP):
    - `dart_mutant` (open-source, Rust-based, 40+ mutation operators) used periodically to verify that tests actually catch bugs, not just execute lines
    - Run against the business logic and data layers; not required for UI or generated code

The front end should be on iOS and Android mobile phones (using Flutter)
The phone should not do the heavy lifting in route generation, this should be handled by the backend
We should use Firebase services for authentication, database and storage

Backend Hosting:
  - Route generation runs on **Cloud Run** as a **Python** service (not Cloud Functions), because it requires up to 60s execution time and sufficient memory for multi-step API orchestration. Python chosen for strong Anthropic SDK and Google Maps client library support.
  - Lightweight operations (auth triggers, Firestore hooks, simple lookups) use **Cloud Functions**
  - All backend services communicate with the Flutter client via REST or Firebase Realtime listeners

Route generation uses a **Hybrid Approach**:
  - **Base Layer**: Google Maps API for map data, elevation, and constraints
  - **Enrichment Layer**: LLM analysis to identify curvy segments, scenic areas, and optimal stopping points
  - **Validation Layer**: Rule-based quality checks (no U-turns, no pointless detours, highway avoidance)
  - This approach balances cost efficiency (leveraging Google Maps' infrastructure) with intelligence (LLM enhancement)

LLM Cost Controls:
  - Use **Claude Haiku** for the validation/vetting layer (fast, cheap)
  - Use **Claude Sonnet** for route generation, descriptions, and voiceover content (higher quality)
  - Estimated cost per route generation: ~$0.02–$0.05 all-in
  - Cache generated routes by a hash of (start region + user preferences) for 24 hours to avoid redundant generation
  - Enforce a per-user rate limit (e.g. 10 route generations per day in free tier)

For each iteration there is success criteria, we should have user analytics that tell us whether the app is making real world impact
Modularised, scalable design decisions that ensures we can iterate quickly, refactor or remove easily without incurring technical debt or becoming bogged down in fixing errors introduced when adding new functionality.


4. Feature Module: The Intelligent Route Architect

Route generation must be as dynamic as possible

Continuous Improvement Model:
  - "Continuous learning" is defined as a **feedback-driven prompt refinement loop**, not LLM fine-tuning
  - After each ride, users rate the route (1–5 stars) and can optionally tag it (e.g. "too many highways", "great curves", "boring scenery")
  - Ratings and tags are stored in Firestore alongside the full route parameters used to generate it
  - Periodically (monthly/quarterly), failure patterns are analysed and used to refine the LLM system prompts
  - Prompt variants can be A/B tested across small user segments to validate improvements before full rollout

Route Generation Data Flow:
  The LLM does not generate GPS coordinates directly. The actual sequence is:
  1. User submits preferences (start location, distance, duration, curviness, scenery type, lunch stop, loop vs point-to-point)
  2. Backend (Cloud Run) geocodes the start location via Google Maps Geocoding API
  3. Backend queries the Google Maps Elevation API and Roads API to retrieve candidate road segments and elevation data within the target radius
  4. Curviness is scored mathematically on the server: extract polyline geometry, calculate bearing-change rate over distance for each segment
  5. Scenery proximity is scored via Google Maps Places API (parks, forests, coastlines, rivers, nature reserves) within a corridor around each candidate segment
  6. LLM (Claude Sonnet) receives a structured summary of candidate waypoints with their curviness score, elevation profile, scenery tags, and road type — plus user preferences and quality constraints
  7. LLM outputs an ordered list of selected waypoints with brief reasoning
  8. Backend submits those waypoints to the Google Maps Directions API to build the navigable route
  9. Validation layer runs programmatically against the returned polyline (see quality rules below)
  10. If validation fails, the failure reason is passed back to the LLM for waypoint adjustment; maximum 3 retry iterations before returning a best-effort result with a user warning
  11. On passing validation: LLM generates the route narrative and selects waypoints for Street View imagery
  12. Google Street View Static API fetches imagery at scenic and curvy waypoints for the route preview card

Routes should be generated based on the following rules:
  - Each route must have a starting point (either user's address, or them picking a different location)
  - Each route should use user criteria to determine length, duration, route characteristics (lunch stop, loop vs different starting and ending locations, road curviness, motorbike characteristics for fuel stops etc.)
  - Each route should have the following considered in its generation:
      Road curviness
      Scenery - proximity to forests, waterways, coastlines, greenery
      Elevation changes

Each route generation must be checked for quality (validated programmatically against the route polyline):
  - No reusing roads on the same route unless strictly necessary (detected via polyline segment overlap check)
  - No u-turns (detected via bearing reversal within a short distance threshold)
  - No 'pointless turns' and detours (detected via detour ratio: actual segment distance vs crow-flies distance)
  - Route should avoid going through large cities and long motorway stretches (enforced via road-type filtering on Directions API response)

Each route should come with:
  - Street View imagery at scenic and curvy waypoints (via Google Street View Static API)
  - A narrative description of the route and why it was chosen, generated by the LLM
  - A Spotify playlist (see Spotify section below)
  - A restaurant stop at the appropriate point if the user requested one, selected via Google Maps Places API (cuisine type matching user preference, rated 4.0+, not more than 5km off the route bearing)
  - Turn-by-turn navigation (see Navigation section below)

Spotify Playlist Generation:
  - Note: Spotify deprecated their audio-features recommendations endpoint in November 2024
  - The current approach: Claude analyses route characteristics (terrain, mood, duration) and generates a structured "playlist brief" (genre, tempo descriptors, mood keywords, example artists)
  - Backend uses the Spotify Search API to find tracks matching those descriptors
  - Backend creates a new playlist via Spotify's Create Playlist + Add Items APIs and returns the playlist URI to the client
  - Requires Spotify OAuth in the app; user must connect their Spotify account once

Turn-by-Turn Navigation:
  - Implemented using the `google_maps_flutter` Flutter package for map rendering and route polyline display
  - Voice turn instructions delivered via the `flutter_tts` package (on-device TTS)
  - Backend continuously compares the user's GPS position against the route polyline; turn announcements trigger when the user is within a configurable distance threshold of the next manoeuvre
  - This is a significant subsystem and is treated as a dedicated workstream within Phase 3

Offline Ride Support:
  - Before a ride begins, the app pre-caches: the route polyline, map tiles for the route corridor, and all voiceover TTS audio files
  - GPS positioning functions fully offline
  - The user is warned and prompted to download offline data if they attempt to start navigation without it (especially relevant on metered or poor connections)


5. UI/UX Design System
The app must support Theme Awareness (Light, Dark, and System Default).
Key Screens for MVP:
  - Splash/Onboarding: Narrative-driven intro.
  - Garage (Profile): Upload multiple bikes. LLM recognizes make/model/extras. After recognition, results are displayed in editable fields so the user can correct any inaccuracies (make, model, year, colour, trim/extras). Confirmed data is saved to Firestore.
  - The "Scout" (Home): A map interface to set "Vibe" (Distance, Curviness, Scenery type, Loop vs Point-to-Point, Lunch Stop).
  - Route Preview: Route card showing map overview, Street View imagery at key waypoints, narrative description, estimated duration/distance, and Spotify playlist link. User confirms before navigation begins.
  - The Ride: Turn-by-turn navigation with a minimalist "Next Turn" UI and a "Voiceover Toggle." Offline-capable once route is pre-cached.


6. MVP Implementation Plan (The "Build" Order)
MVP success is reached when:
  - Users have a delightful onboarding experience where the system uses LLM integrations to extract information from bike photos, gives affirming, nuanced messages about their particular bikes, noting interesting details about their unique bike
  - Users can generate great motorcycle routes that they actually ride.

Phase 1: Foundation (Current)
  - Setup Flutter + Firebase
  - Implement Auth (Google/Facebook/Email)
  - Setup Cloud Run service skeleton for backend
  - Success: User can log in and see a blank "Garage"

Phase 2: The "Garage" & Vision
  - Implement Image Picker
  - Connect to Claude Vision API to identify bike specs from photos
  - Display recognition results in editable confirmation fields; save confirmed data to Firestore
  - Success: User uploads a photo (live or gallery), receives an affirming LLM-generated message about their motorcycle with interesting facts, and can correct/confirm the bike details

Phase 3: The Route Architect
  - Implement the full route generation data flow on Cloud Run (geocoding → segment scoring → LLM waypoint selection → Directions API → validation loop)
  - Build the route preview card (map, imagery, narrative, duration)
  - Implement turn-by-turn navigation subsystem (google_maps_flutter + flutter_tts)
  - Implement offline pre-caching of route data before ride start
  - Implement user route rating and feedback storage in Firestore
  - Success: User configures a ride, receives a high-quality previewed route, and can navigate it with turn-by-turn voice guidance

Phase 4: Audio & Spotify
  - Implement Spotify OAuth and account linking
  - Integrate Spotify playlist generation (Claude brief → Spotify Search → Create Playlist)
  - Implement voiceover waypoints: pre-generate TTS audio for LLM-written landmark commentary, triggered by GPS position during the ride
  - Success: User's ride has a matched playlist and receives contextual audio commentary at points of interest
