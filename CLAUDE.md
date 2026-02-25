# MotoMuse — Claude Code Instructions

## Project Overview
MotoMuse is an AI-native motorcycle navigation app. Refer to `Design-overview.md` for the full system design.

## Design & Architecture Document Maintenance
Whenever a decision is made during implementation that affects any of the following, update `Design-overview.md` **and** `ARCHITECTURE.md` to reflect it **before ending the session**:

- Technology choices (packages, services, APIs, frameworks)
- Architecture or data flow changes
- Changes to the phased implementation plan or success criteria
- New constraints or quality rules discovered during building
- Any decision that overrides or refines something already written in either document
- Infrastructure changes: new secrets, deployment command changes, new GCP services, new Firestore collections

`Design-overview.md` covers the **what and why** — features, data flows, success criteria, phased plan.
`ARCHITECTURE.md` covers the **how and where** — project structure, GCP config, secrets, deployment commands, service URLs.

Do **not** update these documents for:
- Routine bug fixes that don't change the design
- Minor UI tweaks
- Test additions or refactoring that preserves existing behaviour

When updating, edit the relevant section in place. Do not append a changelog. Each document should always read as a clean, current reference — not a history of changes.

## Git & Version Control
After completing any meaningful unit of work (a feature, a phase step, a significant fix), do the following **before ending the session**:
1. Stage the relevant files
2. Commit with a clear message describing what was done and why
3. Ask the user: "Ready to push to GitHub?" and push immediately if they confirm

Do not batch up multiple sessions of work into one push. Small, frequent pushes keep the remote in sync and mean work is never lost.

Always push to `main` unless the user explicitly requests a feature branch.

## Code Standards
When writing code for this project:
- Write tests alongside the code, not after. Every new function in the business logic or data layer gets a unit test in the same PR.
- Respect the layer coverage thresholds (85% business logic, 80% data, 60% UI, 75% overall). If adding code would drop coverage, add tests to compensate.
- Zero `flutter analyze` errors. If a lint rule in `very_good_analysis` is triggered, fix the code — do not suppress the rule unless there is a documented reason.
- Never include `*.g.dart` or `*.freezed.dart` files in coverage calculations; always exclude them from coverage runs.
- Do not write tests that only verify the happy path for critical flows (route validation, auth, data persistence). Include edge cases and failure modes.

## Tech Stack (for reference)
- Frontend: Flutter (iOS + Android)
- Backend: Cloud Run — Python (route generation service), Cloud Functions (lightweight triggers)
- Database / Auth / Storage: Firebase (Firestore, Firebase Auth, Cloud Storage)
- AI: Claude Sonnet (route generation, descriptions), Claude Haiku (validation layer)
- Maps: Google Maps Platform (Geocoding, Directions, Elevation, Roads, Places, Street View)
- Music: Spotify Web API (OAuth, Search, Create Playlist)
- Navigation: google_maps_flutter + flutter_tts
