# Upgrade 289 — Atomic staff event submission
- One Supabase RPC writes event and product requests transactionally.
- Validates permissions, event window, capacity, business model, product payload, quantities and serving times.
- Checks approved event and ordinary reservation conflicts at request time; Admin approval rechecks.
- Flutter staff event form now uses the atomic RPC instead of multiple sequential writes.
- No kitchen tickets, charges or confirmed reservations created on submission.
## Outstanding
- Specific-table selector not yet wired into staff form (currently sends null).
- Public customer event form and anti-abuse controls not implemented.
- Database migration and Flutter compilation not executed.
- Race-safe protection must be verified across all ordinary booking paths.
