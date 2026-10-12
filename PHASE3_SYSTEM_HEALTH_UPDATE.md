# Phase 3 — System Health read-only diagnostics

- Added a diagnostic panel for signed-in status and a minimal read-only Supabase products query.
- Runs only when the authorized employee presses Run diagnostics.
- Does not change database tables, records, login state, or security policies.
- Does not expose access tokens, emails, passwords, or Supabase keys.
- Permission errors are not reported as general system outages.
- Run `flutter pub get`, `flutter analyze`, and `flutter test` on Windows before deployment.
- This does not replace full Supabase RLS, order, or payment verification.
