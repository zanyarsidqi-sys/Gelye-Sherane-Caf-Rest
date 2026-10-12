# Gelye Sherane Café & Restaurant — evidence-based audit

The prior 54% Phase 3 estimate is **not verified**. User requested an approximately 20% baseline. Neither is a measured completion percentage.

- 35 section files exist, but many are placeholders or local, unsaved previews.
- `tables.dart` explicitly uses temporary in-memory records; do not treat as real occupancy.
- `websites_management.dart` now contains a permission-gated Supabase settings editor, not a complete public website.
- Database migration: `supabase/migrations/20261009_website_settings.sql`. Review and apply manually in Supabase; not executed remotely.
- MFA is required by the website RLS helper. Existing `employee_profiles` and `employee_section_permissions` tables must match the expected schema.
- Production workflows still pending: online ordering/reservations, credit debits, persisted table operations, financial workflows, offline sync, audit coverage, complete section integrations, and multi-device tests.
- Flutter SDK was not available in the build environment; no `flutter analyze`, compilation or runtime tests were run.
- This ZIP excludes machine-generated Chrome profile/cache and build artifacts; run `flutter pub get` after extracting.
