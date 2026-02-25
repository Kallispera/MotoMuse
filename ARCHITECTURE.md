# MotoMuse — System Architecture

## GCP Projects

| Project ID | Purpose |
|------------|---------|
| `motomuse-2b33f` | Firebase project (Auth, Firestore, Storage) |
| `motomuse-488408` | Cloud Run services + Secret Manager |

---

## Components

### Flutter App (Client)
- **Platforms:** iOS + Android
- **Framework:** Flutter (Dart)
- **Connects to:**
  - Firebase Auth — sign-in / session management
  - Firestore — reads/writes user profile, bikes, riding content (locations, restaurants, hotels)
  - Firebase Storage — uploads bike photos
  - Cloud Run backend — POST /analyze-bike, POST /generate-route, POST /geocode-address, POST /home-affirming-message
  - Google Maps (via `google_maps_flutter`) — map display + navigation

---

### Firebase Services (project: `motomuse-2b33f`)
| Service | What it stores / does |
|---------|----------------------|
| Firebase Auth | User accounts (Google OAuth, Email/Password) |
| Firestore | `users/{uid}` profile, `users/{uid}/bikes/{bikeId}` bike records, `riding_locations/{id}`, `restaurants/{id}`, `hotels/{id}` curated riding content |
| Firebase Storage | Bike photos at `bikes/{uid}/{timestamp}.jpg` |

---

### Backend Services (project: `motomuse-488408`, region: `us-central1`)

#### Cloud Run Service — `motomuse-backend`
- **URL:** `https://motomuse-backend-887991427212.us-central1.run.app`
- **Path:** `backend/` in this repo
- **Language:** Python / FastAPI
- **Endpoints:**
  - `POST /analyze-bike` — Bike vision (GPT-5.2 two-phase call)
  - `POST /generate-route` — Route generation pipeline
  - `POST /garage-personality` — Garage personality one-liner (Claude)
  - `POST /geocode-address` — Geocode a home address (Google Geocoding API)
  - `POST /home-affirming-message` — Generate affirming message about closest riding region (Claude Haiku)
- **Secrets injected:** `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_MAPS_API_KEY`

#### Cloud Functions *(planned)*
- Lightweight triggers: auth events, Firestore hooks, simple lookups

---

### Secret Manager (project: `motomuse-488408`)
| Secret name | Used by | Status |
|-------------|---------|--------|
| `openai-api-key` | Bike Vision (GPT-5.2) | ✅ Active |
| `anthropic-api-key` | Route Generation (Claude Sonnet) | ✅ Active |
| `google-maps-api-key` | Route Generation (Geocoding, Directions, Street View) | ✅ Active |
| *(future)* `spotify-client-secret` | Spotify playlist generation | Planned |

---

### External APIs

| API | Used for | Status |
|-----|----------|--------|
| OpenAI GPT-5.2 | Bike vision extraction + affirming message | ✅ Live |
| Anthropic Claude Sonnet | Route waypoint selection, narrative, descriptions | ✅ Live |
| Anthropic Claude Haiku | Home address affirming message generation | ✅ Live |
| Google Maps Geocoding | Convert start address to coordinates | ✅ Live |
| Google Maps Directions | Build navigable route from waypoints | ✅ Live |
| Google Maps Street View Static | Scenic imagery at key waypoints | ✅ Live |
| Google Maps Places | Restaurant/POI lookups | ✅ Live |
| Spotify Web API | Playlist generation (OAuth, Search, Create) | Planned |

---

## Data Flow: Bike Onboarding (Phase 2 — Live)

```
User takes/selects photo
        │
        ▼
Flutter uploads photo → Firebase Storage (bikes/{uid}/{timestamp}.jpg)
        │
        ▼
Flutter calls POST /analyze-bike  ──►  Cloud Run (motomuse-488408, us-central1)
        │                                       │
        │                              GPT-5.2 vision call
        │                              GPT-5.2 text call
        │                                       │
        ◄──────────── BikeAnalysisResult (details + affirming message)
        │
        ▼
BikeReviewScreen: user confirms / edits fields
        │
        ▼
Firestore: users/{uid}/bikes/{bikeId}
```

## Data Flow: Route Generation (Phase 3 — Live)

```
User sets ride preferences (type, distance, curviness, scenery, destination/area)
        │
        ▼
Flutter calls POST /generate-route  ──►  Cloud Run
        │
        ├─ Google Maps Geocoding → start coordinates
        ├─ Reverse geocode → region context
        ├─ Claude Sonnet → waypoint generation (with riding area context if set)
        ├─ Google Maps Directions → navigable polyline (avoid highways/tolls)
        ├─ Waypoint spur snapping (branch-point geometry)
        ├─ Programmatic validation loop (max 5 retries)
        │   ├─ Highway fraction check
        │   ├─ U-turn detection
        │   ├─ Road overlap check
        │   ├─ Dead-end spur detection
        │   └─ Urban density check
        ├─ Claude Sonnet → route narrative
        └─ Google Street View Static → imagery with coverage verification
        │
        ▼
Flutter: Route Preview → map + Street View + narrative + stats
```

### There-and-back routes (Breakfast Run / Overnighter)
```
Same pipeline runs twice:
  1. Outbound leg: start → destination (validate independently)
  2. Extract outbound route summary (roads, towns)
  3. Return leg: destination → start with "avoid outbound roads" context
  4. Narrative covers both legs; Street View from both legs
```

---

## Firestore Collections

### User data
- `users/{uid}` — user profile (country, homeAddress, homeLocation GeoPoint, hasCompletedOnboarding bool, garagePersonality string, garagePersonalityBikeCount int, homeAffirmingMessage string)
- `users/{uid}/bikes/{bikeId}` — bike records (make, model, year, mods, photo URL, personalityLine, affirmingMessage)

### Curated riding content (seeded via `backend/seed_data.py`)
- `riding_locations/{id}` — riding regions (name, description, center/bounds GeoPoints, polygon_points GeoPoint array, tags, scenery type, photo URLs, country, order)
- `restaurants/{id}` — biker-friendly restaurants (name, description, location GeoPoint, riding_location_id, cuisine, price range, country, order)
- `hotels/{id}` — biker-friendly hotels (name, description, location GeoPoint, riding_location_id, price range, biker amenities, country, order)

All curated content is filtered by `country` field. Netherlands (`nl`) is seeded with 8 regions.

---

## Source Code Layout

```
MotoMuse/
├── app/                        # Flutter application
│   ├── lib/
│   │   ├── core/               # routing (GoRouter), theme, shared widgets
│   │   ├── shared/widgets/     # AppShell (bottom nav)
│   │   └── features/
│   │       ├── auth/           # sign-in, auth providers
│   │       ├── garage/         # bike upload, vision, review
│   │       ├── scout/          # route preferences, generation, preview
│   │       ├── explore/        # browse riding locations, restaurants, hotels, map views
│   │       ├── onboarding/    # home address capture, closest region, affirming messages
│   │       └── profile/        # user profile screen, UserProfile domain model & repository
│   └── test/                   # mirrors lib/ structure
├── backend/                    # Cloud Run Python service
│   ├── main.py                 # FastAPI app — /analyze-bike, /generate-route, /geocode-address, /home-affirming-message
│   ├── bike_vision.py          # GPT-5.2 two-phase call logic
│   ├── route_generation.py     # Route pipeline: Claude + Google Maps + validation
│   ├── models.py               # Pydantic request/response models
│   ├── seed_data.py            # Firestore seed script (Netherlands riding content)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── tests/
├── ARCHITECTURE.md             # this file
├── Design-overview.md          # full product & technical design
└── CLAUDE.md                   # instructions for Claude Code
```

---

## Deployment Commands

### Deploy backend to Cloud Run
```bash
gcloud config set project motomuse-488408
gcloud run deploy motomuse-backend \
  --source backend/ \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets="OPENAI_API_KEY=openai-api-key:latest,ANTHROPIC_API_KEY=anthropic-api-key:latest,GOOGLE_MAPS_API_KEY=google-maps-api-key:latest"
```

### Seed Firestore with riding content
```bash
cd backend
export ANTHROPIC_API_KEY=sk-ant-...
export GOOGLE_MAPS_API_KEY=AIza...
# Provide Firebase credentials (one of):
#   a) export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
#   b) Place service account key at backend/firebase-sa-key.json
python seed_data.py          # first run
python seed_data.py --clear  # re-seed (clears existing data first)
```

### Run Flutter app (development)
```bash
cd app
flutter run
```

### Run tests
```bash
# Flutter
cd app && flutter test

# Backend
cd backend && pytest
```

### Git remote
```bash
# Remote is named GitHub-Remote (not origin)
git push GitHub-Remote main
```
