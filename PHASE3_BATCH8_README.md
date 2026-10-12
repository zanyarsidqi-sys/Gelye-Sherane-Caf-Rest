# Phase 3 — Batch 8 (read-only integration)

## Changes
- Menu: toggle between local preview and read-only Supabase `gs_menu_products` records.
- Table Orders / Motel Orders / Kitchen: toggle between local preview and read-only Supabase `gs_orders` records.
- Refresh button, loading/empty/error states, and a maximum of 100 fetched records.
- No production writes were activated. Existing local previews and authentication are retained.

## Requirements and safety
- The optional migration `supabase/migrations/20261009_001_phase3_order_foundation.sql` must first be reviewed against your **actual** database schema. Do not run blindly.
- Live reads rely on Supabase Row Level Security and the logged-in employee's permissions.
- Order lists are read-only, and currently do not show line items or totals.
- This is NOT a fully operational ordering system; live creation, editing, payments, and pricing verification remain pending.

## Windows test
1. Open the project directory in VS Code.
2. Run `flutter pub get`, `flutter analyze`, `flutter run -d chrome`.
3. Check Menu, Table Orders, Motel Orders and Kitchen in local preview mode.
4. Only after migration review, try the read-only toggle and confirm data visibility for each employee role.
5. If live tables are unavailable, the app should display a clear error and allow returning to previews.

Progress: approximately 20% estimated implementation, 0/35 production-verified. This estimate is provisional and is not a test result.
