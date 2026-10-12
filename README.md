# Dılêmın

An adult-only dating application with a live, privacy-first radar, online directory, private one-to-one conversations, and account safety tools. **No swipe or match system.**

> Development milestone: foundation + core screens. Not yet App Store or production launch ready.

## Screens implemented (Flutter)

1. Sign in / register (18+)
2. Live Radar (GLSL glow + Flame particles)
3. Online Now directory, live refresh and search
4. Online user profile
5. New conversation
6. Conversation inbox
7. Chat (text, server-persisted, idempotent send)
8. Safety: report and block profile
9. Account and privacy visibility
10. Edit profile
11. Account deletion confirmation

Animation stack: Flutter, Rive, Lottie, GLSL shaders, and Flame. See [animation architecture](mobile/ANIMATIONS.md).

## Stack

| Layer | Technology |
| --- | --- |
| Mobile | Flutter / Dart (iOS + Android) |
| Backend | Laravel 12 + Sanctum |
| Database | PostgreSQL |
| Presence | Redis, 75-second expiration |
| Locales | de (source), fr, it, en (device language; en fallback) |

All API data comes from the backend. No generated accounts, placeholder user records, or fake radar coordinates. Radar dots are **schematic positions derived from account IDs** and never represent real GPS coordinates.

## Developer setup (macOS)

```bash
brew install git gh php composer python3
# Install Flutter SDK and Xcode / Android SDK first.
bash scripts/bootstrap_macos.sh
```

The script generates normal Flutter mobile-platform folders and a standard Laravel project into `backend/`, applies the versioned Laravel overlay, downloads a hash-verified MIT-licensed Rive asset, and runs Flutter analysis and tests.

1. Configure `backend/.env` with a **dedicated** PostgreSQL DB, Redis, and app secret; never commit credentials.
2. Inspect the migration plan first using `php artisan migrate:status` and `php artisan migrate --pretend`. Apply migrations only to your intended, reviewed database.
3. Start the backend with `php artisan serve` (development only).
4. Start Flutter with `flutter run --dart-define=API_BASE_URL=https://your-reachable-api-host` (HTTPS required; real reachable API host).

Generated `backend/` and platform folders can be tracked in Git after scaffolding. CI generates a fresh Laravel skeleton and runs backend feature tests; the Flutter workflow fetches and verifies its licensed Rive asset before analysis/tests.

## API contract

All routes under `/api/v1`:

- `/auth/register`, `/auth/login`, `/auth/me`, `/auth/logout`
- `/presence/heartbeat`, `/presence/offline`, `/discovery/online`
- `/account/profile`, `/account/visibility`, `/account` (delete)
- `/users/{id}`, `/users/{id}/block`, `/users/{id}/report`
- `/conversations`, `/conversations/{id}/messages`

Social endpoints enforce authenticated identity, blocked-user checks, conversation membership, and server-side rate limits. Message client UUIDs provide retry deduplication. Public profile payloads never contain email, date of birth, or exact location.

## Milestones still required

- Email verification, spam moderation and abuse queue, identity/age assurance where required
- Secure private photo uploads + moderation and presentation
- Realtime message and presence delivery (current refresh/poll model is not WebSocket)
- Push notifications, preferences, user-initiated downloads and data portability
- Deployment provisioning, backups, secrets management and incident response
- Actual Flutter analyzer/tests/real-device Android/iOS build gates and store policy audit

Do not treat this milestone as a production release until these controls are implemented and verified.
