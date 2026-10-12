# Realtime and Push Deployment — Dılêmın

The repository provides integration source, not active cloud infrastructure. Push delivery requires Firebase registration, APNs setup, and real devices. No API keys or service account credentials are included.

## Backend

- Use secure PostgreSQL, Redis and an HTTPS API; configure dedicated Redis queue workers and a persistent Reverb websocket server behind WSS/TLS.
- Install Sanctum, Laravel Reverb, and the Kreait Firebase PHP SDK using the versioned bootstrap script. For reproducible production deployment, track a locked Composer manifest.
- Set APP_KEY, QUEUE_CONNECTION=redis, BROADCAST_CONNECTION=reverb.
- Provide REVERB_APP_ID, REVERB_APP_KEY (public in Flutter), REVERB_APP_SECRET (server-only), REVERB_SERVER_HOST, REVERB_SERVER_PORT, REVERB_HOST, REVERB_PORT, REVERB_SCHEME=https.
- Run php artisan reverb:start with a process supervisor; independently run php artisan queue:work redis --queue=default,push --tries=3 --timeout=60 under a supervisor. Never run only synchronous queues in production.
- Private channel authorization is a Sanctum-protected POST to /api/v1/realtime/authorize. Authorization rejects outsiders, unverified accounts, and blocked users. Do not publish conversations on public channels.
- Inspect the non-destructive migration plan before applying migrations in the correct database. Do not perform production resets.

## Firebase native setup

1. Create separate Android/iOS Firebase apps, enable FCM, and use flutterfire configure to provision genuine native Firebase configuration in a private build environment. google-services.json and GoogleService-Info.plist are git-ignored.
2. Configure Apple APNs entitlement, Push Notifications capability, Background Modes > Remote notifications and an APNs .p8 key in Firebase with Key ID and Team ID.
3. Create a Firebase service account with narrowly scoped FCM sending permission. Keep the JSON outside the repository and set FIREBASE_CREDENTIALS to its absolute server path.
4. Supply Flutter build defines API_BASE_URL (HTTPS), REVERB_WS_URL (WSS base host), REVERB_APP_KEY (public), and ENABLE_PUSH=true. Without real native Firebase configuration, ENABLE_PUSH remains false.
5. The verified user must grant push permission. The mobile app registers its device token via authenticated PUT /api/v1/push/devices and revokes it via DELETE; tokens are stored encrypted and bound to the Sanctum token lifecycle.
6. The queue delivers generic de/fr/it/en notification text, with no message body, photo, or exact geolocation. Foreground messages refresh chats; tapping a background/terminated notification re-opens a conversation only after checking current API access.
7. FCM/APNs background delivery varies by OS version, permissions, connectivity, and force-quit behavior. Never claim guaranteed execution after a user force-quits.

## Required release verification

- End-to-end device runs for iOS and Android in foreground, background, and normal terminated states, with production-equivalent APNs configuration.
- WebSocket event receipt/reconnect on unstable networks; unauthorized, blocked, and unverified socket subscriptions.
- Multi-device token rotation, sign-out and account deletion, failed job retries, sender errors and pruning stale push tokens.
- Operational monitoring, worker supervision, encrypted secret storage, incident response, backups and disaster recovery.
- Photo and report moderation staffing, privacy policy and retention, app store compliance, and age assurance appropriate to release regions.
