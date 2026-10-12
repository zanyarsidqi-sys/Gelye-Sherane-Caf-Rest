# Upgrade 219 — Unified quantity-aware delivery

- Disabled the old whole-item pickup/delivery transitions at the database RPC boundary; kitchen status progression remains available.
- Table item dialog no longer offers the deprecated pickup/delivered buttons. Staff use My Jobs → Quantity handover.
- Snapshot RPC explicitly rejects ambiguous legacy `picked_up` records without ledger quantities; manual audited reconciliation is required, not guessed.
- Existing historical whole-item deliveries are preserved. No invented backfill.
- Quantity ledger remains authoritative for new handovers and job completion.

Verification: ZIP CRC and unique paths checked; static assertions passed. Flutter compile, live Supabase migrations, RLS, concurrency, and migration compatibility NOT tested.
Tables progress: 93% estimated; Customers remains paused at 45%.
