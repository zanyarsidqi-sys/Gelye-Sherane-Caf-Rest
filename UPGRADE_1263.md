# Upgrade 1263 — Dashboard responsive metric cards

- Changed only `lib/screens/dashboard/dashboard_screen.dart`.
- Dashboard metric cards now use two columns from 340 logical pixels (previously 400) if text scale is at most 1.3; large accessibility text retains one column.
- Added finite-width fallback and non-negative card width clamping for narrow layouts.
- Preserved existing data loading, permissions, actions and tablet/desktop columns.
- Static source checks performed; Flutter compile and device tests not performed.
