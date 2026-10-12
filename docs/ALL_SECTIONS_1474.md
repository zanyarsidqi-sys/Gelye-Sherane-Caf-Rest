# Upgrade 1474: universal 35-section context

Every one of the 35 registered management sections uses `SectionShell`; this upgrade adds one shared, permission-gated context banner to every section rather than making unrelated one-off changes. The banner identifies the current section and warns that financial totals require independent reconciliation. It does not certify any amount or modify payments. Existing search/filter, section content, navigation, footer, permissions, and financial migrations are preserved.

## Staging validation (not executed)

1. Apply previous migrations on isolated Supabase staging.
2. Run existing diagnostics for prepaid allocation, journal, and identity mapping with approved test records.
3. Verify denied users cannot see the new banner or protected section data.
4. Visit all 35 sections on iPhone and Windows and check the banner, navigation, footer and filters.
5. Verify invoice-to-order evidence independently before enabling settlement.

## Rollback

Restore the prior `lib/shared/section_shell.dart`; no database schema changes were made by this upgrade.
