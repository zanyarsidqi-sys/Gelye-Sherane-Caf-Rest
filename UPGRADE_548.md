# Upgrade 548 — Kitchen receipt exception safeguards

- Adds an audit-exceptions-only filter to the revision dispatch dialog.
- Surfaces actionable manager escalation for reconciliation inconsistencies.
- Disables kitchen receipt acknowledgment and failed-dispatch retry if reconciliation is unavailable, the dispatch is absent from reconciliation, or an audit mismatch is detected.
- Leaves backend financial records and kitchen receipts untouched; no automatic repairs.
- Requires migration 546 and all earlier migrations.

Verification: source assertions and ZIP integrity only. Flutter compilation and live Supabase integration tests were not performed.
