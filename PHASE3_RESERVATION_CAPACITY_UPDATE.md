# Phase 3 — Reservation capacity guard (development update)

Implemented in migration `20261009_010_reservation_capacity_guard.sql`:
- Staff can configure real reservable tables through permission-checked `gs_set_reservable_table` RPC.
- Staff approval automatically assigns the smallest suitable available table.
- A two-hour default reservation duration (configurable in DB) is used to detect overlaps.
- A transaction advisory lock prevents simultaneous approvals from double-assigning tables.
- An approval fails if no suitable table exists; the request remains pending.
- Existing review audit logging is retained.

**Before using:** deploy migrations in order; populate actual table inventory via the RPC; validate permissions and real-world operating rules. No physical table inventory has been invented or seeded. This does not implement CAPTCHA, rate limiting, table combining, opening hours, staff scheduling, customer notification, or end-to-end tests. The project has not been Flutter-compiled or database-tested here.

**Progress:** historical 54% is not a verified measurement. 35 section-level production verifications remain, and additional implementation remains. This change does not justify a new numeric percentage.
