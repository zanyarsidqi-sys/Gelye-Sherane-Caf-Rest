# Upgrade 154 — Reservation cancellation UI

- Added a permission-scoped cancellation queue RPC for pending/approved reservations not checked in.
- Added a Tables screen cancellation picker and explicit confirmation.
- Uses the existing `gs_cancel_reservation(uuid)` function for server-side permission checks, status validation and audit logging.
- Prevents attempting to cancel a checked-in reservation from the queue; existing cancellation RPC still controls final authorization.
- Flutter and SQL source assembled into the full project ZIP. Not compiled or run against Supabase.
- **Section 02 — Tables: 23% estimated (0–100), not production-verified.**
- Going forward track a distinct 0–100% estimate for every one of the 35 sections; do not infer verification from source presence.
