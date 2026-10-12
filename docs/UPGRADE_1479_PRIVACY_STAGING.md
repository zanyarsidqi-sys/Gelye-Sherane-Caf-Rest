# Upgrade 1479 — All-section privacy safety and staging readiness

## Shared change across 35/35 registered management sections
`lib/shared/section_shell.dart` now automatically conceals protected content when
Flutter enters inactive, paused, hidden, or detached states. Authentication changes
also lock the section before rechecking access. Switching section identity locks
content and resets workflow search. Unlock requires a fresh server-backed check.
This applies to every section using SectionShell, including authorizedContent.

## Financial staging
`supabase/diagnostics/financial_staging_schema_1479.sql` is a read-only schema
smoke check wrapped in BEGIN/ROLLBACK. Run only against a disposable staging
Supabase PostgreSQL database after migrations. It does not verify actual payment
posting, authentic provider receipts, source-document identities, invoice status,
concurrency, or ledger reconciliation. None of those are certified.

## Status
- No provider credentials or staging connection available to execute live SQL.
- No Flutter build or real device execution in this upgrade.
- Standing Cash and Pending Payment IQD totals remain uncertified.
- Preserve prior ZIP for rollback.
