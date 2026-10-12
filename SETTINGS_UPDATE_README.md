# Phase 3 - Settings & Rules local preferences

- Added `lib/shared/settings_rules_panel.dart`.
- Routed `settings_rules` to this screen inside the existing permission-gated SectionShell.
- Employee-scoped local storage for three preferences; reset supported.
- These preferences are not yet wired into global layout/action behavior and are labeled accordingly.
- No Supabase schema changes. No backend rules, pricing, MFA, RLS, or payment behavior modified.
- Windows Flutter compilation and UI testing still required.
