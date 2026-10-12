# Account security & data portability

## Sessions

`GET /api/v1/auth/sessions` returns at most the user's most recent 100 access tokens, their last activity, expiry, and whether they represent the requesting access token. It never exposes token secrets.

`DELETE /api/v1/auth/sessions/{id}` revokes a *different* token owned by the authenticated account. Unauthorized or cross-account IDs produce 404.

`POST /api/v1/auth/sessions/revoke-others` revokes every other token. The current bearer token stays active, and the endpoint requires the account password.

Sessions expire after 30 days from token creation; expired tokens are not automatically removed from the database without a cleanup job. A user with multiple devices may briefly reappear as offline after one device signs out, until their next heartbeat. Presence is not yet device-scoped.

## Personal export

`POST /api/v1/account/export` requires verified authentication and the account password. It sends a `no-store` JSON download containing the account, own blocked IDs, submitted reports, messages in conversations the user belongs to, and the user's own JPEG (base64, including unapproved images). No other user's email, birthdate or photo is exported. Foreign conversations are not exported. All database messages are iterated using a cursor rather than a PHP in-memory list.

The Flutter screen writes the HTTPS response to a temporary file and opens the native iOS/Android share sheet. It deletes the local temporary file after the share sheet returns. Users can share/export sensitive content to other apps at their own discretion. Cloud backups, device-specific share extensions and filesystem behavior should be verified on real devices before launch.

The export is a versioned snapshot and is not a continuous backup. API rate limit: 3 exports per authenticated account per hour.

## Release gates still open

- CI Flutter analysis, backend tests, real-device iOS/Android builds and security review must pass on this commit.
- OS push notifications, realtime events, age assurance, location permissions, moderation operations and data retention/deletion policies need completion before release.
- Don't store authentication tokens or secrets in a public repository.
