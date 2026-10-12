# Dashboard Upgrade 84 — Append-only payment ledger

Added a draft migration enforcing **append-only** behavior for all unified
payment ledger entries, including entries not linked to legacy cash receipts.
Existing Upgrade 83 protected only reconciled rows.

Added an insert-time structural guard for refund/reversal records:
- the referenced original must exist;
- both records must belong to the same order;
- the original must be a credit entry;
- a single reversal cannot exceed its original entry;
- non-refund entries cannot claim an original entry.

**Not yet solved:** cumulative refunds across concurrent transactions,
trusted payment verification and posting, source authentication, accounting
allocation, or actual bill transfer. A row satisfying these checks is NOT
proof that money was paid or refunded.

Before deploying, verify migration compatibility and backfill requirements
on a disposable Supabase staging database. The ZIP passed integrity checks,
but no SQL was executed and Flutter was not compiled.
