# Upgrade 1353 — Fail-closed Pending Payment invoice diagnostics

Strengthened the existing permission-gated read-only motel invoice integrity function. NULL/nonpositive invoice totals, missing statuses or source counts, invalid settlement amounts, and multiple cash settlement rows now require finance review. No payment collection is enabled; Standing Cash code remains unchanged.

Verification: archive CRC and static Python contract test only. Live Supabase and Flutter tests not run.
