# Gelye Sherane Cafe & Restaurant — Flutter UI Starter v1.0.0.29

**35 management sections, 35 separate Dart screen files** in `lib/sections/`. A responsive public landing screen and staff UI demonstration are included. This is **not** a finished café management application, and the staff demo deliberately has **no authentication**. Do not deploy to production.

## Windows + Visual Studio Code

1. Install Git, Flutter SDK, VS Code with Flutter/Dart extensions, and Android Studio (for Android SDK). Use `flutter doctor -v` to verify.
2. Extract this ZIP to a local folder, e.g. `C:\CafeProjects\gelye_cafe`.
3. In VS Code: **File > Open Folder**, choose `gelye_cafe`.
4. Open Terminal in that folder and run:

```powershell
flutter create --platforms=windows,web,android .
flutter pub get
flutter run -d chrome
```

The `flutter create` command generates the platform runner folders that are intentionally not shipped here; it does not replace `lib/` screens. To run Windows desktop, install **Visual Studio 2022 with Desktop development with C++** (Visual Studio Code alone is not enough for Windows builds), then `flutter run -d windows`.

Run `flutter test` after platform setup. **Flutter SDK is not installed in the package build environment, so this app has not been compiled here.**

## Design

- `lib/main.dart`: entrypoint
- `lib/app/cafe_app.dart`: public landing, responsive 35-section navigation, light/dark theme
- `lib/app/section_registry.dart`: one registry for 35 separate screens
- `lib/sections/*.dart`: exactly 35 independent screens
- `lib/shared/section_shell.dart`: reusable scaffold and temporary in-memory demo notes
- `lib/security/README.md`: authentication/RBAC/MFA integration requirements
- `lib/services/README.md`: Supabase/local server/SQLite/sync integration requirements

## Mandatory work before production

- Implement real public menu/orders and employee authentication, MFA, role permissions, server-side authorization, RLS, and audited actions.
- Implement financial correctness, payment/refund rules, kitchen workflow, inventory, and 35 actual business modules. Current pages are placeholders with ephemeral demo notes.
- Implement device offline storage and café LAN server, durable queue, idempotency, conflict resolution, and sync audit.
- Integrate with the separately maintained SQL/Node backend **only after** real PostgreSQL migration/security tests and API contracts are verified.
- Validate Windows/Android/Web builds, restore testing, load tests, employee acceptance tests, and production release gates.

**Existing backend package:** `gelye_master_v1.0.0.28.zip` is separate. The Flutter starter version is `v1.0.0.29`.
