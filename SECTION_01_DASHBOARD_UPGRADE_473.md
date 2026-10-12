# Upgrade 473 — Dashboard lifecycle refresh and mobile layout resilience

- Dashboard refreshes its permission-scoped operational metrics when the app returns to foreground, reducing stale counts after staff use other sections.
- Pull-to-refresh errors are shown by the existing FutureBuilder rather than bubbling as an unhandled refresh exception.
- Fail-closed response metadata validation requires the expected Baghdad timezone and server timestamp.
- Dashboard metric grid now supports one-column narrow widths and fixed tile height to avoid clipping on iPhone and desktop text scaling.
- No new database migration; the existing Upgrade 472 permission-scoped RPC remains authoritative.

## Remaining verification
Run `flutter analyze`, widget tests with narrow widths and text scaling, authenticated permission matrix, and Supabase live tests. These were not executed in this environment.

## Historical section estimates
01 Dashboard: under reassessment, not yet substantiated above 90%; 02 Tables: 94% historical; 03 Table Orders: 69% historical; 04 Motel Orders: 91% development estimate. None verified 100%.
