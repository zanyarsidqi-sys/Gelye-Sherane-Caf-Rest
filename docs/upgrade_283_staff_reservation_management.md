# Upgrade 283 — Staff reservation management

- Added permission-protected RPC `gs_staff_specific_reservations` for staff-only listing of pending/approved specific-table reservations.
- Added responsive Flutter staff reservation management screen for table transfer, reschedule, and cancellation with required cancellation reason.
- Connected actions to existing Upgrade 280 `gs_staff_change_specific_reservation` RPC, which enforces authorization, serialization, availability and before/after audit.
- Added entry point to Tables workspace; preserved existing check-in and cancellation controls.
- Existing SQL migration 280 must be applied before 283.

## Unverified / remaining
Flutter compilation and live Supabase migration/function tests were not performed. Staff listing currently requires website edit permission (matching the existing change RPC). Pending event reservation approval and advance product preparation are future work. Production review should validate timezone behavior, RLS, all reservation status transitions and concurrency under real users.
