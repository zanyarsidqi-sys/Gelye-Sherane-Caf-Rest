# Dashboard Upgrade 74 — SQL migration compatibility audit (static)

## Applied correction
Updated migration `20261009_052_visit_bound_cart_order_draft.sql` to conditionally
revoke a legacy order RPC **only if that exact signature exists**. Previously
an unconditional REVOKE could abort a fresh database migration when the
optional legacy function was absent.

The patch changes only migration compatibility; it does not bypass the
active-visit requirement or enable payments, bill transfers or owner waivers.

## Static migration inventory
- SQL migration files reviewed: 70
- Repeated SQL function names (not necessarily errors): 10
- These names need signature and execution-order review:
- `cafe_can_manage_website`: 20261009_005_website_settings.sql, 20261009_website_settings.sql
- `gs_consume_stock_when_served`: 20261009_029_recipe_ingredient_consumption.sql, 20261009_027_kitchen_inventory_consumption.sql
- `gs_create_cart_order`: 20261009_019_atomic_cart_orders.sql, 20261009_020_cart_integrity_guards.sql, 20261009_052_visit_bound_cart_order_draft.sql
- `gs_dashboard_overview`: 20261009_033_dashboard_tables_and_trends.sql, 20261009_034_dashboard_alerts_cash_trends.sql, 20261009_031_dashboard_live_overview.sql, 20261009_032_dashboard_accuracy_permissions.sql
- `gs_dashboard_week`: 20261009_033_dashboard_tables_and_trends.sql, 20261009_034_dashboard_alerts_cash_trends.sql
- `gs_record_cash_payment`: 20261009_021_cash_payment_ledger.sql, 20261009_062_cash_payment_interlock_draft.sql
- `gs_staff_review_public_request`: 20261009_010_reservation_capacity_guard.sql, 20261009_012_public_order_kitchen_bridge.sql, 20261009_009_staff_public_request_review.sql
- `gs_submit_public_order`: 20261009_008_public_order_requests.sql, 20261009_011_public_request_validation.sql, 20261009_014_customer_order_tracking.sql
- `gs_submit_reservation_request`: 20261009_011_public_request_validation.sql, 20261009_007_public_reservation_requests.sql
- `gs_update_cafe_table`: 20261009_016_live_tables.sql, 20261009_018_table_release_order_guard.sql, 20261009_045_checkout_cleaning_safety_draft.sql

## Still unresolved
- Repeated `CREATE OR REPLACE FUNCTION` statements can be intentional,
  but each signature and downstream permission grant must be checked.
- Draft migrations may assume existing table columns, audit structures,
  role strings, or privileges not present in a clean deployment.
- Some draft RPCs are deliberately fail-closed and will block workflows.
- Migration filename order is not sufficient proof of dependency safety.
- Historical orders, unified settlement, credit/online payments, and owner
  waivers still need a production migration strategy.

## Test procedure for a development computer
1. Provision a disposable Supabase staging project; NEVER run draft migrations
   against production without review and backups.
2. Apply migrations in order and capture the first PostgreSQL error.
3. Compare RPC signatures with the Flutter call sites.
4. Verify RLS policies and authenticated/anonymous execution grants.
5. Test active table visits, cart orders, payment races, guest movements,
   complimentary requests, and rejected unauthorized actions.
6. Run Flutter analyzer and compile for iPhone, Windows and web.

**Verification level:** static source audit and ZIP CRC only. No PostgreSQL
execution, Flutter compilation, or live Supabase tests were performed.
