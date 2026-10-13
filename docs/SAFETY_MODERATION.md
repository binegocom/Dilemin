# Dılêmın safety moderation

All report decisions are taken by authenticated, email-verified staff accounts. Do not automatically suspend accounts based solely on the number of reports.

- A reviewer may dismiss, mark reviewed or suspend a reported non-staff account after documenting a reason.
- Suspension sets `suspended_at`, clears online visibility and blocks discovery, messaging, photos and new private-channel authorizations. Existing ephemeral presence is removed when Redis is available, and otherwise expires.
- A suspended member may still sign in, export their own data, delete their account or sign out. These exceptions are intentional.
- Moderator actions are recorded in `moderation_actions` with staff ID, account ID, referenced report where applicable, action, reason, and timestamps.
- Staff accounts cannot be suspended or restored through the ordinary report queue.
- Restoration is a separately audited moderator action. Profiles remain invisible until users explicitly enable visibility.
- Moderators must follow a documented escalation, appeals, evidence handling and retention process before release. This repository does not replace human moderation operations.
- Review `php artisan migrate --pretend` against the selected database before applying the new non-destructive migration. Do not run resets against production.

Regression tests must derive report IDs from API responses or insert results. PostgreSQL sequences do not roll back with transactional test isolation.

## Suspension appeals

- An email-verified, suspended member can submit **one** appeal for each distinct suspension using `POST /api/v1/account/appeal`. A database uniqueness constraint prevents duplicate submissions; the current suspension timestamp binds each request to the action being contested.
- The member can read only their own appeal and decision at `GET /api/v1/account/appeal`; social discovery and chat remain disabled while review is pending. Sign-out, personal data export and account deletion remain available.
- Moderators use the private `GET /api/v1/moderation/appeals` queue and `POST /api/v1/moderation/appeals/{id}/review` with `decision: restored|rejected` and a required written note. Only one review can succeed. The decision and reviewer are recorded; restoring leaves online visibility disabled.
- A separate manual staff restoration closes any pending appeal for the matching suspension, avoiding stale moderation tasks.
- Personal appeal statements are included only in their owner's password-confirmed JSON export. The application must not put appeals, decision notes, or evidence into public profiles, analytics events, push content or unauthenticated logs.
- Assign a human moderation team, define response-time targets, an escalation channel for urgent safety allegations, an off-app contact path for access problems, a retention period for evidence, and an appeal dispute procedure before public release.
- Automated checks verify that suspended accounts cannot use social endpoints, that decisions and duplicate attempts are auditable, and that export data is scoped to the signed-in account.

The appeal workflow does **not** perform identity verification, determine legal age, or replace human safety operations. Age-verification requirements depend on the launch jurisdiction and need separate compliance assessment.
