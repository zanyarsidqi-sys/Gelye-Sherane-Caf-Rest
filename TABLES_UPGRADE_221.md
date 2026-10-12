# Upgrade 221 — Reservation-aware guest-count movement

- Advisory preview now warns when destination has an approved reservation active now or beginning in the next 30 minutes.
- Atomic guest-count execution repeats this guard and takes the reservation advisory transaction lock before table/visit row locks.
- No reservation is cancelled, changed or transferred. Orders and payments remain untouched.
- Guard uses existing numeric table labels, `approved` status, and reservation duration.
- Apply migration 221 after 220. Validate with concurrent reservation approvals and guest moves in staging.
- No Flutter compilation or live Supabase migration was performed.
- Section 02 estimated progress 94%; do not increase without integration verification.
