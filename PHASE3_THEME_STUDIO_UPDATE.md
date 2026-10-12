# Phase 3 Appearance Studio

- Added `lib/shared/appearance_preferences_panel.dart` for System / Light / Dark selection.
- Wired `appearance_dark_mode` to the new panel through the existing authorized SectionShell.
- Saved selection in SharedPreferences and added a theme preview.
- Root app reads the new preference on startup; existing quick toggle saves its choice.
- No Supabase schema, permissions, payment, or authentication changes.
- Flutter analyzer and runtime verification still required on user's Windows machine.
