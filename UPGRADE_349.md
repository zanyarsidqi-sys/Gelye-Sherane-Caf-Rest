# Upgrade 349 — Kitchen visibility for scheduled motel meals

- Added a Kitchen tab showing approved scheduled motel meals with room, description, requested time, and status.
- Read-only RPC requires Kitchen `can_view` permission. Pending/rejected requests are excluded.
- No kitchen ticket, room charge, or fulfillment transition is created; this is operational visibility only.
- Requires migration `20261010_349_kitchen_scheduled_motel_visibility.sql`.
- Flutter compilation and live Supabase migration remain untested.
