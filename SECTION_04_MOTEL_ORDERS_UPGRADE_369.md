# Upgrade 369 — Invoice Handoff Verification

Added `gs_staff_motel_food_invoice_handoff_manifest(guest_session_id)` as a read-only, permission-checked RPC. It returns itemized staging-ledger identifiers and amounts only when an existing employee review has a matching identity-level fingerprint, all delivered orders are staged, and every charge matches the guest session, room, status, and line-item total. It rejects outdated reviews and inconsistent ledgers. The guest stay is locked for the duration of the function, consistent with review workflows.

**Not implemented:** official invoice creation, payment posting, credit deductions, or any removal of the ledger's `invoice_id IS NULL` constraint. Integrating the existing order-centric payment architecture requires a dedicated financial schema mapping and live tests.

Section 04 progress remains **73% estimated**. ZIP integrity verified; Flutter compilation and live Supabase migration have not been tested.
