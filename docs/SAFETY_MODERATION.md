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
