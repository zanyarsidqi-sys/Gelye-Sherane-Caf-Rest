# Dashboard Upgrade 27 — System Audit foundation

- New read-only employee audit history screen with search, event details, refresh.
- iPhone full-screen and Windows right-side panel.
- Permission gated in UI and server RPC (`dashboard` + `security_access_control`).
- Draft migration 036 creates protected audit event storage and read RPC.
- No audit event producers/triggers yet: existing actions are NOT automatically logged.
- Backend migration is NOT deployed, Flutter is NOT compiled, and tests are deferred.
- Next: transactional server-side event producers, sensitive-field redaction, tamper protection, pagination, filters, and per-action coverage.
