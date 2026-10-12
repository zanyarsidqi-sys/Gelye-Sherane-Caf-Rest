# Upgrade 360 — Motel food ledger reconciliation

Adds a staff-only read-only reconciliation RPC and a summary panel to the Food Ledger tab.
Compares delivered food orders to staging ledger entries, detects missing entries,
amount mismatches, and entries whose orders are no longer delivered. Displays totals in IQD.

This is **not** official invoice integration. No payment posting or invoice mutation is performed.

Validation: ZIP integrity and file-presence checks only; Flutter compilation and live Supabase
migration execution are not available in this environment.
