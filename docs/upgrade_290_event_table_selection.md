# Upgrade 290 — Specific-table event selection

- Staff event form now queries eligible tables for chosen event start/end and guest count.
- Staff may choose a specific table or submit without one.
- Backend read-only RPC checks capacity and overlap with approved event and normal bookings.
- Existing atomic submission revalidates selected table; Admin approval must revalidate too.

## Remaining
- Public event intake, CAPTCHA/rate limiting, comprehensive event kitchen/billing workflows.
- Live Supabase deployment and Flutter compilation not performed.
- Preview is not a reservation hold; concurrency safety across every booking path needs live testing.
