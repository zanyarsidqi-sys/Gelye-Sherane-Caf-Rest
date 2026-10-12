# Upgrade 1351 — Standing Cash cross-channel blocker diagnostics

Added `gs_standing_cash_settlement_blockers(bigint)` as a read-only, permission-gated diagnostic. It counts existing unified ledger entries, external payment evidence, owner offers and table bill transfers, and incorporates the cash receipt anomaly review flag. The result explicitly never authorizes collection or confirms settlement.

Pending Payment collection remains disabled until invoice-level canonical settlement and idempotency are validated.

Verification: ZIP integrity, source contract checks; no live Supabase migration or Flutter build was run.
