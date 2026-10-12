# Upgrade 1492 — build repairs and shared session protection

Source: Gelye_Cafe_Rest_1491(2).zip, supplied 12 October 2026.
This updates the Restaurant project only. It does not update Café & Sweet.

## Implemented changes
- Repaired six Dart test imports that still used the old gelye_cafe package name.
- Repaired Table Orders string syntax and a loading label that referenced another widget's pagination state. Service jobs now display an accurate loading message.
- Repaired motel room registry dialog syntax and the accidental duplicate nested ListView; preserved room registration, editing, guest-code issuance and revocation controls.
- Repaired the public reservation form's closing structure.
- Corrected invalid Wrap arguments in customer, credit, order creation, kitchen delivery, motel finance, and reservation controls; retained their actions.
- Corrected invalid const declarations in dashboard, reconciliation, payments, feedback, and customer-call widgets, and fixed icon-button label arguments.
- Shared protection for all 35 sections: EmployeePermissionService now verifies profile ownership and binds asynchronous profile/permission results to the initiating employee AND access token. Account changes, replacement tokens, sign-out and loss of MFA reject stale results. Profile and permission requests have 12-second timeouts.
- Saved-login verification now times out an unresponsive user lookup and rejects mismatched server identity or a changed initiating session. Failure never authorizes management access.
- Added 12 executable simulated-HTTP session tests. Dependency injection supports isolated tests without changing the production Supabase client default.
- Refreshed the dependency lockfile to include dependencies already declared but missing from the old lockfile. Added an explicit HTTP test dependency.

## Verification actually performed
Environment: Flutter 3.47.7, Dart 3.13.5, Linux.
- Initial Dart analyzer: 70 error diagnostics. After repairs: ZERO errors; 23 warnings and 338 informational diagnostics remained at the recorded analysis pass. This is not a warning-free analysis result.
- Full Flutter test suite: 68 passed, 0 failed, including all 12 new session tests and the exactly-35-unique-sections test.
- Existing Upgrade 1491 Python source checks: 5 passed. These are source checks, not live database integration tests.
- JavaScript release web build: PASSED.
- Second release web build with synthetic non-production Supabase defines: PASSED. This ensures the configured management path also compiles. No live backend was contacted for verification.
- The secure-storage dependency reports WebAssembly incompatibilities during the dry run. The ordinary JavaScript web build succeeds. A Cupertino icon-font warning also remains.

## Remaining work / limits
- Supply the approved Restaurant SUPABASE_URL, SUPABASE_ANON_KEY (public key only), and SUPABASE_EXPECTED_PROJECT_REF when building the actual connected app.
- Verify real staff sign-in/MFA, revoked permissions, RLS, payments, reconciliation and migrations against an authorized staging project. No settlement, payment total, database rollout or production security certification is claimed.
- Native iPhone/Android/Windows builds, visual/device validation, physical printers and offline sync are not verified by these web/unit tests.
- Existing analysis warnings, incomplete workflows and Wasm support remain further work. Overall project completion is not measured by the upgrade number.

## Reproduce
From the project root with Flutter installed:
1. flutter pub get
2. dart analyze
3. flutter test --no-pub
4. flutter build web --release --dart-define-from-file=YOUR_APPROVED_CONFIG.json
The configuration JSON must contain the three SUPABASE_* keys above. Never include a service-role or secret server key in a client build.

## Preservation / rollback
All original archive entries are retained. Navigation, the 35-section registry, footer, MFA gates and Supabase migrations are preserved. No database was changed. Restore the previous uploaded ZIP/version to roll back this source-only checkpoint.
Generated SDK/cache/build directories are not included; this remains the complete source project. See verification_1492.json and verification_logs/1492/ for evidence and changed-file hashes.
