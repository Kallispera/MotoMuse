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
  1. User submits preferences (start location, distance, curviness, scenery type, loop, route type, optional destination/riding area)
  2. Backend (Cloud Run) geocodes the start location via Google Maps Geocoding API
  3. Backend dispatches based on route type:
     - **Day Out** (default): generates a circular or point-to-point route as below
     - **Breakfast Run / Overnighter**: generates a there-and-back route with two legs on different roads (see below)
  4. LLM (Claude Sonnet) generates waypoints using regional context (riding area name/bounds if specified), user preferences, and quality constraints
  5. Backend submits those waypoints to the Google Maps Directions API to build the navigable route
  6. Validation layer runs programmatically against the returned polyline (see quality rules below)
  7. If validation fails, the failure reason is passed back to the LLM for waypoint adjustment; maximum 5 retry iterations before returning a best-effort result with a user warning
  8. On passing validation: LLM generates the route narrative and selects waypoints for Street View imagery
  9. Google Street View Static API fetches imagery at scenic and curvy waypoints (with coverage verification) for the route preview card

  There-and-back route generation (breakfast run / overnighter):
  - Step 1: Generate outbound waypoints (start → destination) via Claude Sonnet
  - Step 2: Build outbound route via Directions API, validate independently
  - Step 3: Extract outbound route summary (road names, towns passed)
  - Step 4: Generate return waypoints (destination → start) with "avoid outbound roads" prompt context
  - Step 5: Build return route via Directions API, validate independently
  - Step 6: Generate narrative covering both legs
  - Step 7: Fetch Street View images for both legs separately

Routes should be generated based on the following rules:
  - Each route must have a starting point (either user's address, or them picking a different location)
  - Each route should use user criteria to determine length, duration, route characteristics (lunch stop, loop vs different starting and ending locations, road curviness, motorbike characteristics for fuel stops etc.)
  - Each route should have the following considered in its generation:
      Road curviness
      Scenery - proximity to forests, waterways, coastlines, greenery
      Elevation changes

Regional Riding Knowledge:
  - Route generation is informed by curated riding content stored in Firestore collections (`riding_locations`, `restaurants`, `hotels`), filtered by country
  - When a user selects a riding area on the Scout screen, the area name, center coordinates, and radius are passed to the backend and injected into the Claude Sonnet waypoint generation prompt, biasing waypoints into that region
  - Waypoints are biased toward areas known for excellent motorcycling (twisty roads, scenic passes, coastal routes, mountain roads) rather than placed purely by geometric distance from the start point
  - Regional data is seeded via `backend/seed_data.py` which uses Claude Sonnet to research regions and Google APIs for photos; new countries can be added by extending the seed script
  - Netherlands is the first seeded country with 8 riding regions, each with associated restaurants and hotels
  - As the feedback loop matures (see Continuous Improvement Model), user ratings further reinforce or adjust which regional areas produce highly-rated rides

Each route generation must be checked for quality (validated programmatically against the route polyline):
  - No reusing roads on the same route unless strictly necessary (detected via polyline segment overlap check, 300m sampling, 3% threshold)
  - No u-turns (detected via bearing reversal within a short distance threshold)
  - No dead-end spurs (detected via polyline path/distance ratio; also caught by waypoint-level U-turn detection + geometric branch-point snapping before validation)
  - No 'pointless turns' and detours (detected via detour ratio: actual segment distance vs crow-flies distance)
  - Route should avoid going through large cities and long motorway stretches (enforced via road-type filtering on Directions API response)
  - No excessive urban routing (detected via short-step fraction, 30% threshold)

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
  - The "Scout" (Home): Ride type selector (Breakfast Run / Day Out / Overnighter) with conditional controls per type. Breakfast Run and Overnighter show destination pickers from curated Firestore data; Day Out shows optional riding area picker. Common controls: curviness, scenery type, distance (Day Out only), loop toggle (Day Out without area only).
  - Explore: Browse curated riding content — three tabs for Locations, Restaurants, and Hotels. Each card links to a detail screen with CTA buttons that deep-link to Scout with preferences pre-filled. Detail screens include "View on map" buttons showing polygon outlines for regions and point markers for restaurants/hotels.
  - Route Preview: Route card showing map overview (two polylines for there-and-back routes: gold outbound, dashed blueGrey return), Street View imagery at key waypoints (combined from both legs), narrative description, estimated duration/distance per leg, and Spotify playlist link. User confirms before navigation begins.
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
  - Scout screen built: ride type selector (Breakfast Run / Day Out / Overnighter), distance slider, curviness stars, scenery chip selector, loop/one-way toggle, lunch stop toggle, GPS start location auto-fill via geolocator, destination/area pickers from curated Firestore data ✅
  - Cloud Run /generate-route endpoint: pipeline — geocoding → reverse-geocode region context → Claude Sonnet waypoint generation (with riding area context if specified) → Directions API (avoid highways/tolls) → waypoint spur snapping (geometric U-turn detection + branch-point snap) → programmatic validation (highways, U-turns, overlap, dead-end spurs, urban density) with up to 5 retry cycles → Claude narrative → Street View Static images with coverage verification; supports three route types with there-and-back generation for breakfast runs and overnighters ✅
  - Route preview screen: google_maps_flutter map with decoded polyline (two polylines for there-and-back routes), Street View image horizontal scroll, route stats (per-leg for two-leg routes), LLM narrative, destination name display ✅
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

Phase 5: Regional Riding Content & Route Types (✅ Complete — Netherlands)
  Curated riding content:
  - Three new Firestore top-level collections: `riding_locations/{id}`, `restaurants/{id}`, `hotels/{id}` — filtered by `country` field (starting with "nl")
  - `riding_locations`: name, description, center GeoPoint, bounds (NE/SW), photo URLs (Street View), tags, scenery type, display order
  - `restaurants`: name, description, location GeoPoint, riding_location_id (denormalized name), cuisine type, price range, photo URLs, display order
  - `hotels`: name, description, location GeoPoint, riding_location_id (denormalized name), price range, biker amenities list, photo URLs, display order
  - Seed script (`backend/seed_data.py`): uses Claude Sonnet to research and generate descriptions for 8 Netherlands regions + restaurants/hotels per region; fetches Google Street View imagery; writes to Firestore via firebase-admin SDK
  - 8 seeded Netherlands regions: South Limburg, Veluwe, Zeeland Coast, Drenthe, Achterhoek, Utrechtse Heuvelrug, Overijssel Salland, Noord-Brabant Kempen

  Explore feature (Flutter):
  - New `features/explore/` module following domain → data → application → presentation clean architecture
  - Explore tab added as 4th tab (Garage, Scout, Explore, Profile) in AppShell bottom navigation
  - Three sub-tabs: Locations, Restaurants, Hotels — each showing scrollable card lists from Firestore
  - Detail screens for each content type with photo carousels, descriptions, and CTA buttons
  - Deep links: "Plan a breakfast run" (restaurant) / "Plan a ride here" (location) / "Plan an overnighter" (hotel) → navigates to Scout with preferences pre-filled
  - Firestore repository uses real-time streams ordered by `order` field

  Three route types:
  - **Breakfast Run**: User selects a restaurant from curated list → scenic 1-2h ride each way → there-and-back on different roads
  - **Day Out**: Optional riding area selection → circular route exploring that area; or general circular route (existing behaviour)
  - **Overnighter**: User selects a hotel from curated list → scenic 4-6h ride each way → there-and-back on different roads
  - Scout screen: SegmentedButton ride type selector with conditional UI per type (restaurant picker, area picker, hotel picker, adaptive distance/loop controls)
  - Route preview: two-polyline map (gold outbound, dashed blueGrey return), separate stats per leg, combined Street View carousel, destination name display

  Backend route type system:
  - `RoutePreferences` extended: `route_type`, `destination_lat/lng/name`, `riding_area_lat/lng/radius_km/name`
  - `RouteResult` extended: `return_polyline`, `return_distance_km`, `return_duration_min`, `return_waypoints`, `return_street_view_urls`, `route_type`, `destination_name`
  - There-and-back pipeline: generates outbound leg (start → destination), extracts route summary, generates return leg (destination → start) with "avoid outbound roads" prompt context, validates each leg independently
  - Day Out with riding area: Claude waypoint prompt includes area name/center/radius to bias waypoints into the specified region
  - 97 backend tests pass (7 new tests for route type dispatching, there-and-back assembly, riding area context)

  - New Flutter packages: none (uses existing google_maps_flutter, cloud_firestore, flutter_riverpod)
  - New backend packages: firebase-admin >=6.0.0 (seed script only)
  - 142 Flutter tests pass; 0 flutter analyze errors ✅
  - Success: Users can browse curated Netherlands riding content, plan rides to specific restaurants/hotels with scenic there-and-back routes on different roads, and explore regional riding areas ✅

Phase 6: Map Views, Home Address Onboarding & Persistent Affirming Messages (✅ Complete)
  Map views for explore content:
  - "View on Map" button added to LocationDetailScreen, RestaurantDetailScreen, and HotelDetailScreen
  - Reusable `ItemMapScreen` with named constructors (`.location()`, `.restaurant()`, `.hotel()`)
  - Riding regions displayed with polygon boundary outlines (semi-transparent amber/gold fill, 3px stroke)
  - Restaurants and hotels displayed as single point markers
  - Polygon coordinates (6-10 points per region) added to seed script and `riding_locations` Firestore documents
  - `RidingLocation` model extended with `polygonPoints: List<LatLng>` field (backward-compatible default `const []`)
  - Falls back to bounding box rectangle when polygon data is empty

  Home address onboarding:
  - `HomeAddressScreen` captures the rider's home address after their first bike addition
  - Geocoding via new `POST /geocode-address` backend endpoint (Google Geocoding API, server-side)
  - Closest riding region calculated using Haversine distance formula
  - Affirming message generated via new `POST /home-affirming-message` backend endpoint (Claude Haiku)
  - Address, geocoded coordinates, and affirming message permanently saved to `users/{uid}`
  - Onboarding trigger: `GarageScreen` watches `needsOnboardingProvider` and redirects to address screen
  - "Skip for now" option marks onboarding complete without address

  Persistent affirming messages:
  - Per-bike `affirmingMessage` and `personalityLine`: already saved in Firestore (no change needed)
  - Garage personality banner: now cached in `users/{uid}/garagePersonality` with `garagePersonalityBikeCount`; only regenerated when bike count changes (eliminates redundant Cloud Run calls)
  - Home affirming message: generated once and saved in `users/{uid}/homeAffirmingMessage`

  User profile domain model:
  - New `UserProfile` value object and `FirestoreUserProfileRepository` in `features/profile/`
  - Fields: uid, homeAddress, homeLocation, country, hasCompletedOnboarding, garagePersonality, garagePersonalityBikeCount, homeAffirmingMessage
  - Onboarding providers in `features/onboarding/application/`

  - New backend endpoints: `POST /geocode-address`, `POST /home-affirming-message`
  - 162 Flutter tests pass; 0 flutter analyze errors ✅
  - Success: Riders can see their riding areas on a map with polygon outlines, view restaurants/hotels as map markers, and receive a personalized affirming message about their closest riding region during onboarding ✅
