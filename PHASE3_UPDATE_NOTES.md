# Gelye Sherane Cafe — Phase 3 Navigation Update

This is an incremental source update, NOT a complete Phase 3 implementation.

Changes:
- Dashboard cards now navigate via the existing permission-checked ManagementDashboard._openSection method.
- Cards are only interactive when their target section ID is present in allowedSections.
- Tourism Customers currently opens Customers (there is no dedicated tourism-customers module in the uploaded registry).
- Today Orders opens Table Orders (there is no separate today-orders module).
- All original authorization, MFA, and session files were retained unchanged.

Important limitations:
- Most sections remain placeholder modules marked UNDER DEVELOPMENT.
- Dashboard figures are not connected to Supabase data.
- Supabase database schema/migrations were not included in the uploaded ZIP.
- Flutter/Dart SDKs are unavailable in this execution environment; this update was checked structurally, not compiled or runtime-tested.

Windows test:
1. Back up your original project.
2. Extract this ZIP to a NEW folder.
3. Open the folder containing pubspec.yaml in VS Code.
4. Run: flutter pub get
5. Run: flutter analyze
6. Run: flutter run -d chrome
7. Log in and test authorized and unauthorized dashboard card navigation.

Do not put service-role secrets or passwords into the project ZIP.
