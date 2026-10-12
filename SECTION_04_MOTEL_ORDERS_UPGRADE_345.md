# Upgrade 345 — Guest scheduled-meal status tracking

Adds read-only guest-scoped RPC `gs_public_motel_meal_status` and a refreshable list on the verified customer QR screen. Only meal requests from the exact verified temporary guest session are returned. Does not expose other stays or room bills. Kitchen dispatch, live order tracking, and active occupancy linkage remain pending. Flutter compile and live Supabase migration not tested. Section 04 progress estimated 41%.
