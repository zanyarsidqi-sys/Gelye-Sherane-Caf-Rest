# Upgrade 280 — Staff reservation modifications and cancellation

Implemented `gs_staff_change_specific_reservation`, a permission-checked Supabase RPC allowing authorized staff to reschedule an existing pending or approved reservation, transfer its specific table, or cancel with a required reason. The RPC uses the same advisory transaction lock as Upgrade 279 to serialize changes against confirmations, verifies time horizon, table capacity and approved-booking overlaps, and preserves the original reservation ID.

A new restricted `gs_reservation_change_audit` table captures full before/after records, employee ID, reason and timestamp. Existing request-review audit also records the transition. All modifications are server-side; anonymous clients cannot execute this RPC. No changes to historical order or invoice records.

## Verification and remaining work
- Static inspection only; migration has **not** been applied to live Supabase and Flutter compilation has **not** been performed.
- Verify whether `cancelled` is allowed by the reservation status constraint in the deployed schema before applying migration; update it in a reviewed migration if not.
- Audit snapshots include customer contact information: restrict database access, apply retention controls and avoid exposing them in public APIs.
- Public booking endpoint still needs edge CAPTCHA and production rate limiting; public/staff Flutter reservation forms and real-device testing remain incomplete.
- Next: Upgrade 281, integrate public and staff reservation UI with the existing reservation RPCs, without exposing customer private data.
