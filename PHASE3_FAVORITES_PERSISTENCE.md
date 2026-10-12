# Phase 3: Persistent favorites and ordering

- Favorites are now stored locally using `shared_preferences`, keyed by the authenticated Supabase user ID.
- Favorites are restored after authorization and filtered to currently authorized sections.
- Employees can move favorite sections up/down; order is saved on the same device.
- This is **device-local persistence**, not cross-device sync. No database schema or RLS changes.
- Run `flutter pub get`, `flutter analyze`, and `flutter run -d chrome` on Windows.
- Test two different employee accounts on the same device, refresh, log out and back in, and verify unauthorized sections remain hidden.
