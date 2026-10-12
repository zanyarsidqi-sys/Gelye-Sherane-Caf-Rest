# Upgrade 467 — Previous-section review and staff concern visibility

## Implemented
- Connected the existing permission-controlled customer concern review RPC (Upgrade 466) to the employee credit authorization dialog.
- Employee can now inspect reported invoice, timestamp, and concern reason, without enabling payment or consent.

## Prior-section audit (static inspection only)
Review scope: Dashboard, Tables, Table Orders, Motel Orders. This is a code-inventory review, **not** VS Code, Supabase or runtime verification.

### Dashboard
- Matching Dart source files: 6.
- Examples: lib/sections/dashboard.dart, lib/screens/dashboard/dashboard_insights.dart, lib/screens/dashboard/table_dashboard_details.dart, lib/screens/dashboard/dashboard_cloud_preferences.dart, lib/screens/dashboard/dashboard_integration_review.dart
- Required next verification: route/navigation, role-based permissions, Supabase RPC/RLS, responsive iPhone/Windows rendering, real workflow integration.

### Tables
- Matching Dart source files: 1.
- Examples: lib/sections/tables.dart
- Required next verification: route/navigation, role-based permissions, Supabase RPC/RLS, responsive iPhone/Windows rendering, real workflow integration.

### Table Orders
- Matching Dart source files: 1.
- Examples: lib/sections/table_orders.dart
- Required next verification: route/navigation, role-based permissions, Supabase RPC/RLS, responsive iPhone/Windows rendering, real workflow integration.

### Motel Orders
- Matching Dart source files: 1.
- Examples: lib/sections/motel_orders.dart
- Required next verification: route/navigation, role-based permissions, Supabase RPC/RLS, responsive iPhone/Windows rendering, real workflow integration.

## Release gates before declaring any section 100%
1. `flutter pub get`, `flutter analyze`, platform build and widget/integration tests.
2. Apply all pending migrations in a disposable Supabase environment; validate SQL signatures, RLS and authenticated RPCs.
3. End-to-end Dashboard → Tables → Table Orders → Motel Orders and accounting reconciliation.
4. Confirm guest QR security, pricing modes, cancellations, audit history and payment protections.
5. Confirm credit identity, customer consent, account balance/limit and idempotency before any debit is enabled.

## Verification performed
- Python source edit and ZIP CRC verification only; Flutter and live Supabase not available.
- Section 04 remains **91% estimated**; verified completion percentage is unknown.
