# Upgrade 343 — Guest scheduled special meal request

Added guest-side scheduled meal request form after reception-issued access code verification. The server rechecks QR room identity, session validity and expiry for every request, enforces 15-minute to 90-day delivery window, 3–500 character description, and five requests/hour/session. Requests enter the existing staff scheduled meals list with `requested` status; no charge or kitchen ticket is created. Room QR alone is insufficient.

Outstanding: automatic live occupancy integration, guest order status, meal approval, kitchen dispatch, translations, Flutter compilation, live Supabase migration/testing.
