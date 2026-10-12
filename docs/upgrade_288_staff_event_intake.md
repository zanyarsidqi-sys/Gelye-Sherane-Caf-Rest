# Upgrade 288 — Staff event request form

- Added `StaffEventRequestScreen` and Tables action.
- Event date/time, guest count, business model, services, and multiple advance products/quantities.
- Calls existing permission-protected event and product RPCs.
- All requests remain pending Admin approval; no automatic kitchen tickets or charges.

## Known gaps
- Product RPC writes are sequential, not atomic: if one fails, Admin must review the incomplete pending event.
- Specific-table selection, per-product serving time, product catalog mapping, rental quote, public intake and rate limiting remain pending.
- UI uses device-local time; explicit Asia/Baghdad conversion remains pending.
- Flutter compilation and live Supabase testing not performed.
