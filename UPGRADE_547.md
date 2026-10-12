# Upgrade 547 — Kitchen receipt reconciliation visibility

Adds a read-only reconciliation RPC call to the Table Orders revision dialog, with per-dispatch audit states, an inconsistency count, explicit unavailable/error state, and manager-review warnings. Does not automatically repair financial or kitchen records. Requires migration 546.

Verification: source assertions and ZIP integrity only. Flutter compilation and live Supabase tests not run.
