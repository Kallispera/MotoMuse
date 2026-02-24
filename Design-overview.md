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
  - **Bike vision service** (`backend/`): Cloud Run Python/FastAPI service, deployed now. Handles `POST /analyze-bike` — two-phase GPT-5.2 call for vision extraction + affirming message. OPENAI_API_KEY injected via Cloud Secret Manager at deploy time.
  - **Route generation service**: Cloud Run Python (not Cloud Functions), because it requires up to 60s execution time and sufficient memory for multi-step API orchestration. Python chosen for strong Anthropic SDK and Google Maps client library support.
  - Lightweight operations (auth triggers, Firestore hooks, simple lookups) use **Cloud Functions**
  - All backend services communicate with the Flutter client via REST or Firebase Realtime listeners

Route generation uses a **Hybrid Approach**:
  - **Base Layer**: Google Maps API for map data, elevation, and constraints
  - **Enrichment Layer**: LLM analysis to identify curvy segments, scenic areas, and optimal stopping points
  - **Validation Layer**: Rule-based quality checks (no U-turns, no pointless detours, highway avoidance)
  - This approach balances cost efficiency (leveraging Google Maps' infrastructure) with intelligence (LLM enhancement)

LLM Cost Controls:
  - Use **GPT-5.2** (OpenAI) for the Garage vision phase: two-phase call per bike upload (vision extraction + affirming message). Estimated ~$0.01–$0.03 per upload.
  - Use **Claude Haiku** for the route validation/vetting layer (fast, cheap)
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

Regional Riding Knowledge:
  - Route generation should be informed by knowledge of renowned riding roads and regions for the user's country/locale
  - On registration, the user's country (derived from locale or sign-up location) is stored on their profile and used as context for route generation
  - The LLM prompt for waypoint selection includes region-specific riding knowledge — e.g. for the UK: Welsh valleys, Scottish Highlands, Peak District, North Yorkshire Moors; for the US: Blue Ridge Parkway, Pacific Coast Highway, Tail of the Dragon, etc.
  - Waypoints should be biased toward areas known for excellent motorcycling (twisty roads, scenic passes, coastal routes, mountain roads) rather than placed purely by geometric distance from the start point
  - Over multiple route generations, a user's routes should naturally explore the best riding areas accessible from their region, not just radiate outward from their start location
  - This knowledge is supplied to the LLM via the system prompt as structured regional data, not hard-coded in application logic — making it easy to expand to new countries and refine over time
  - As the feedback loop matures (see Continuous Improvement Model), user ratings further reinforce or adjust which regional areas produce highly-rated rides
  - Regional data is maintained as a curated knowledge file (or Firestore collection) that maps country/region to notable riding areas with brief descriptors (road character, scenery type, elevation profile, best season)

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

Phase 1: Foundation (✅ Complete)
  - Setup Flutter + Firebase ✅
  - Implement Auth ✅
    - Google OAuth (via google_sign_in) and Email/Password implemented
    - Facebook sign-in deferred — requires Facebook Developer App setup; button removed from sign-in screen until configured
    - On first sign-in, a user profile document is created in Firestore (users/{uid})
    - Auth packages: firebase_auth ^5.0.0, google_sign_in ^6.2.0, cloud_firestore ^5.0.0
    - Testing: fake_cloud_firestore ^3.0.0 used in data-layer tests (avoids mocking sealed Firestore classes)
    - Router is auth-aware: unauthenticated users are redirected to /sign-in; authenticated users skip it
    - Router implemented as a Riverpod Provider<GoRouter> with a _RouterNotifier ChangeNotifier bridging auth state to GoRouter.refreshListenable
  - Setup Cloud Run service skeleton for backend (next step)
  - Success: User can log in and see a blank "Garage" ✅

Phase 2: The "Garage" & Vision (✅ Complete)
  - Image picker (camera + gallery) via `image_picker ^1.1.0` ✅
  - Photo uploaded to Firebase Storage at `bikes/{uid}/{timestamp}.jpg` ✅
  - Cloud Run Python (FastAPI) service added at `backend/` — receives the Storage download URL and performs a two-phase GPT-5.2 call: ✅
      Phase 1 (vision): extracts make, model, year, displacement, colour, trim, modifications, category, and distinctive features from the photo as structured JSON
      Phase 2 (text): generates a personalised 2–3 sentence affirming message about the specific bike, drawing on its history, engineering, and culture
  - AI model used: GPT-5.2 (OpenAI) for both vision extraction and message generation; model constant `VISION_MODEL = "gpt-5.2"` in `backend/bike_vision.py`
  - LLM cost estimate: ~$0.01–$0.03 per bike upload (vision call + text call)
  - BikeReviewScreen: affirming message displayed in a gold-accented card; all extracted fields are editable; modifications shown as deletable chips with add capability ✅
  - Confirmed bike saved to Firestore at `users/{uid}/bikes/{bikeId}` ✅
  - New Flutter packages: `image_picker ^1.1.0`, `firebase_storage ^12.0.0`, `http ^1.2.0` ✅
  - Success: User uploads a photo (live or gallery), receives an affirming LLM-generated message about their motorcycle with interesting details, and can correct/confirm the bike details ✅

Phase 3: The Route Architect (✅ Core route generation complete)
  Phase 3a — Route generation and map display (complete):
  - Scout screen built: distance slider, curviness stars, scenery chip selector, loop/one-way toggle, lunch stop toggle, GPS start location auto-fill via geolocator ✅
  - Cloud Run /generate-route endpoint: nine-step pipeline — geocoding → geometric candidate waypoints → Elevation API scoring → Places API scenery scoring → Claude Sonnet waypoint selection → Directions API (avoid highways/tolls) → programmatic validation (U-turns, highway %) with up to 3 LLM retry cycles → Claude narrative → Street View Static images ✅
  - Route preview screen: google_maps_flutter map with decoded polyline, Street View image horizontal scroll, route stats, LLM narrative ✅
  - New Flutter packages: geolocator ^13.0.0, google_maps_flutter ^2.9.0 ✅
  - New backend packages: googlemaps 4.10.0, anthropic 0.49.0 (Claude Sonnet for route selection and narrative) ✅
  - Claude Sonnet (claude-sonnet-4-6) used for waypoint selection and route narrative ✅
  - LLM cost estimate per route generation: ~$0.01–$0.03 (Claude Sonnet, 2 calls) + Google Maps API calls
  - Backend deployed to Cloud Run; GOOGLE_MAPS_API_KEY added to Secret Manager alongside OPENAI_API_KEY ✅
  - 142 Flutter tests pass; 0 flutter analyze errors ✅

  Phase 3b — Deferred to later iteration:
  - Turn-by-turn navigation subsystem (google_maps_flutter + flutter_tts)
  - Offline pre-caching of route data before ride start
  - User route rating and feedback storage in Firestore

  - Success: User configures a ride on the Scout screen, receives a high-quality route displayed on a map with Street View imagery and a narrative description ✅

Phase 4: Audio & Spotify
  - Implement Spotify OAuth and account linking
  - Integrate Spotify playlist generation (Claude brief → Spotify Search → Create Playlist)
  - Implement voiceover waypoints: pre-generate TTS audio for LLM-written landmark commentary, triggered by GPS position during the ride
  - Success: User's ride has a matched playlist and receives contextual audio commentary at points of interest

Phase 5: Regional Riding Intelligence
  - Build curated regional riding knowledge dataset (start with UK, US, EU core countries) mapping country/region to notable riding roads and areas with descriptors (road character, scenery type, elevation, best season)
  - Store as a Firestore collection or structured knowledge file loadable by the route generation service
  - Capture user country/locale at registration and persist on the user profile document
  - Update the Claude Sonnet route generation prompt to include relevant regional riding knowledge as context, biasing waypoint selection toward known-good riding areas
  - Instrument analytics to track whether routes touching known riding areas receive higher user ratings than those that don't
  - Iterate regional data based on user feedback and rating patterns (ties into Continuous Improvement Model)
  - Success: Routes consistently guide riders toward the best riding roads in their region; users report discovering roads they wouldn't have found on their own
