# Dashboard Upgrade 90 — Reconciliation mismatch guards

This increment updates the existing **read-only** reconciliation RPC (same
signature) to count mismatched cash-to-ledger crosswalks as exceptions.
It checks order IDs, amounts, entry type, direction and source system.
It also counts provisional overpayments as exceptions and reports a clear
warning rather than silently treating those numbers as settlement.

**No money is posted, no bill is transferred, and settlement_confirmed and
transfer_allowed remain false.** A zero-exception diagnostic is not proof
of settlement. This change must be tested against staging migrations.

Verification: ZIP CRC and static text assertions only. No live Supabase,
Flutter build, or device tests performed.
