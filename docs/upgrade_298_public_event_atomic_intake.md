# Upgrade 298 — Public event atomic submission backend
- Service-role-only RPC validates all event fields, product quantities, venue scope and selected tables.
- Atomic insertion of event, selected tables, and advance product requests.
- Checks conflicts against approved ordinary reservations and events; Admin approval still required.
- Edge Function verifies Turnstile and per-IP rate limits before invoking RPC; returns pending_admin.
- Public Flutter form remains disabled: it still needs a Turnstile widget/token and public table availability integration.
- Live database migrations, concurrency tests, Edge deployment, and Flutter compilation not performed.
- Security review required for trusted proxy IP and abuse throttling, including repeated invalid payloads.
