# Section 1 Dashboard — update and remaining verification

## Added
- Supabase-backed KPI screen, mobile/desktop responsive metrics and operations shortcuts.
- Date picker and refresh, loading/error/empty states.
- Permission-scoped order metrics and separate finance permissions.
- Migration 032 hardens migration 031 by scoping financial amounts to accessible order types.
- Clarified that order value is not cash received and cash receipts can belong to prior-day orders.
- Narrow screens use one column; currency values scale down to avoid clipping.

## Not yet verified / incomplete
- Run `flutter analyze` and `flutter run -d chrome` on the user's computer.
- Deploy migrations 001–032 in order, including 031 then 032.
- Test role combinations, especially kitchen-only, order-only, finance-only, motel-only and mixed permissions.
- Confirm business date behavior across midnight in Asia/Baghdad.
- Confirm live totals against cash ledger and order detail data, including cancellations.
- Validate iPhone and Windows layouts, accessibility and all navigation links.
- Dashboard does not yet provide full charts, table occupancy or real-time subscriptions.
- Cash is not total revenue; credit/card integrations remain separate.

Section 1 is NOT approved until these checks pass.
