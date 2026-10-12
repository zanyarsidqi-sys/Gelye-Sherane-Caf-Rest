# Upgrade 1383: Standing Cash and Pending Payment

- Standing Cash order rows explicitly explain why Receive cash is disabled when server eligibility is false. No change to server checks, receipt reference, or posting logic.
- Pending Payment refresh now reloads both source invoices and settlement allocation diagnostics, preventing stale evidence after a refresh. Collection remains blocked.
- Existing Cash Reconciliation files unchanged.
- Static source assertions and ZIP integrity verified. Flutter compile and live Supabase verification unavailable; screenshot similarity unmeasured.
