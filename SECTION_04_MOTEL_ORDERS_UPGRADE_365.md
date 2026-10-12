# Upgrade 365 — Invoice review completeness guard

- Employee review now rejects guest stays with delivered food orders missing from the staging ledger.
- Checks guest-session and room consistency between order and ledger.
- Existing review status now flags missing delivered orders and invalid or changed ledger entries, even when the total has not changed.
- Employee UI labels stale reviews via tooltip.
- No official invoice, charge, or payment posting.
- Flutter build and live Supabase migration not tested in this environment.
- Section 04 estimated progress: 71%.
