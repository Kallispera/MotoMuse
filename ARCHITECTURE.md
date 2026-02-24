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
  - Firestore — reads/writes user profile, bikes, routes
  - Firebase Storage — uploads bike photos
  - Cloud Run (bike vision service) — POST /analyze-bike
  - Google Maps (via `google_maps_flutter`) — map display + navigation

---

### Firebase Services (project: `motomuse-2b33f`)
| Service | What it stores / does |
|---------|----------------------|
| Firebase Auth | User accounts (Google OAuth, Email/Password) |
| Firestore | `users/{uid}` profile, `users/{uid}/bikes/{bikeId}` bike records, routes, ratings |
| Firebase Storage | Bike photos at `bikes/{uid}/{timestamp}.jpg` |

---

### Backend Services (project: `motomuse-488408`, region: `us-central1`)

#### Bike Vision Service — Cloud Run
- **URL:** `https://motomuse-backend-887991427212.us-central1.run.app`
- **Path:** `backend/` in this repo
- **Language:** Python / FastAPI
- **Endpoint:** `POST /analyze-bike`
- **What it does:**
  1. Receives a Firebase Storage download URL
  2. Phase 1: GPT-5.2 vision call → extracts make, model, year, colour, trim, mods, category
  3. Phase 2: GPT-5.2 text call → generates a personalised affirming message about the bike
  4. Returns structured JSON to the Flutter app
- **Secrets:** `OPENAI_API_KEY` injected from Secret Manager at deploy time
- **Cost:** ~$0.01–$0.03 per bike upload

#### Route Generation Service — Cloud Run *(Phase 3, not yet built)*
- **Language:** Python
- **Why Cloud Run (not Functions):** needs up to 60s execution + memory for multi-step API orchestration
- **What it will do:** geocoding → road segment scoring → LLM waypoint selection → Directions API → validation loop

#### Cloud Functions *(planned)*
- Lightweight triggers: auth events, Firestore hooks, simple lookups

---

### Secret Manager (project: `motomuse-488408`)
| Secret name | Used by |
|-------------|---------|
| `openai-api-key` | Bike Vision Cloud Run service |
| *(future)* `anthropic-api-key` | Route Generation Cloud Run service |
| *(future)* `google-maps-api-key` | Route Generation Cloud Run service |
| *(future)* `spotify-client-secret` | Route Generation Cloud Run service |

---

### External APIs

| API | Used for | Phase |
|-----|----------|-------|
| OpenAI GPT-5.2 | Bike vision extraction + affirming message | Phase 2 ✅ |
| Anthropic Claude Sonnet | Route generation, narrative, voiceover | Phase 3 |
| Anthropic Claude Haiku | Route validation layer | Phase 3 |
| Google Maps Geocoding | Convert start address to coordinates | Phase 3 |
| Google Maps Directions | Build navigable route from waypoints | Phase 3 |
| Google Maps Elevation | Elevation profile of road segments | Phase 3 |
| Google Maps Roads | Road segment geometry + type | Phase 3 |
| Google Maps Places | Scenic proximity, restaurant stops | Phase 3 |
| Google Maps Street View | Imagery at scenic waypoints | Phase 3 |
| Spotify Web API | Playlist generation (OAuth, Search, Create) | Phase 4 |

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

## Data Flow: Route Generation (Phase 3 — Planned)

```
User sets ride preferences (distance, curviness, scenery, loop?)
        │
        ▼
Flutter calls Cloud Run route service
        │
        ├─ Google Maps Geocoding → start coordinates
        ├─ Google Maps Roads + Elevation → candidate segments
        ├─ Curviness score (bearing-change rate, server-side)
        ├─ Scenery score (Google Maps Places proximity)
        ├─ Claude Sonnet → selects + orders waypoints
        ├─ Google Maps Directions → navigable polyline
        ├─ Validation loop (max 3 retries via Claude Haiku)
        ├─ Claude Sonnet → route narrative + voiceover text
        └─ Google Street View → imagery at key waypoints
        │
        ▼
Flutter: Route Preview card → user confirms → navigation begins
```

---

## Source Code Layout

```
MotoMuse/
├── app/                        # Flutter application
│   ├── lib/
│   │   ├── core/               # routing, theme, shared widgets
│   │   └── features/
│   │       ├── auth/           # sign-in, auth providers
│   │       └── garage/         # bike upload, vision, review
│   └── test/                   # mirrors lib/ structure
├── backend/                    # Cloud Run Python service
│   ├── main.py                 # FastAPI app, POST /analyze-bike
│   ├── bike_vision.py          # GPT-5.2 two-phase call logic
│   ├── models.py               # Pydantic request/response models
│   ├── Dockerfile
│   ├── requirements.txt
│   └── tests/
├── ARCHITECTURE.md             # this file
├── Design-overview.md          # full product & technical design
└── CLAUDE.md                   # instructions for Claude Code
```

---

## Deployment Commands

### Deploy bike vision service
```bash
# From repo root, in the PowerShell window where gcloud works
gcloud config set project motomuse-488408
gcloud run deploy motomuse-backend \
  --source backend/ \
  --region us-central1 \
  --allow-unauthenticated \
  --set-secrets="OPENAI_API_KEY=openai-api-key:latest"
```

### Run Flutter app (development)
```bash
cd app
flutter run
```
