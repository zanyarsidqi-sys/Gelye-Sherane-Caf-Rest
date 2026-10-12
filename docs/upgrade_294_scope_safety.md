# Upgrade 294 — Multi-table event request backend and approval safety

Added staff-only RPC to assign 1–30 unique tables to a pending event with aggregate capacity validation and consistent locking. Added database trigger to **block approval** of whole-venue and multi-table requests until all relevant ordinary-reservation paths have atomic venue/table locking. This is intentionally fail-closed: it does not claim whole-venue or multi-table bookings are operational. Customer-facing selection and public submission remain pending. No live Supabase migration or Flutter compilation performed.
