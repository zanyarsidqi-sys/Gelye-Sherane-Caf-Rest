# Upgrade 1223 — station device login backend checkpoint

- Adds service-role-only RPCs for station password validation, issuing hashed bearer-token sessions, checking session expiry/revocation, updating device heartbeats and manager revocation.
- Adds Supabase Edge Function `station-device-auth` for login and heartbeat. Raw bearer token is returned only on login; the database stores its SHA-256 hash. The token must be stored in the device secure keystore (not in plaintext preferences).
- WARNING: SQL login-failure inserts roll back when an exception is raised, so the included database attempt counter DOES NOT reliably throttle invalid passwords. **DO NOT DEPLOY LOGIN TO PRODUCTION** until a durable external per-IP and per-username rate limiter is integrated and verified. The Edge Function currently lacks that limiter.
- Station device credentials do not authorize employee actions; do not expose service-role credentials to Flutter.
- No Flutter login screen or secure token persistence yet; no actual POS printing or print retries yet; printer-ready heartbeat is a client claim, not independently verified printer health.
- Supabase migrations and Edge Function untested. This is source code only, not production-ready authentication.
