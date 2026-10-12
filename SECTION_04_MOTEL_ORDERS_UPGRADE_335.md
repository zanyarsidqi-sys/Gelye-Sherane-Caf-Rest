# Upgrade 335 — Room registry
Adds staff-only room registration, name and accommodation type editing using existing `gs_motel_room_qr` identities. QR tokens are unchanged when metadata changes. Room registration does NOT prove an active guest stay. Apply migration 335 after 334. Requires Flutter compile and live Supabase permission tests.
