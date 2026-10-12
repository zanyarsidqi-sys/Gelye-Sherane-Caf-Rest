# Phase 3 — Product Catalog Readiness

Added `lib/shared/inventory_catalog_panel.dart` and wired it into the authorized `products_inventory` section.

- Read-only query of up to 200 RLS-accessible `gs_menu_products` rows.
- Search by product name/barcode; filter active/inactive, missing barcode, missing/zero prices.
- Refresh, clear catalog counts, and Normal/Tourism price display.
- No stock quantity, low-stock, stock movement, or purchase-ledger claims. These require a reviewed stock schema and server-side permissions.
- No migrations, authentication changes, or data writes.

Verification deferred: `flutter pub get`, `flutter analyze`, `flutter run -d chrome`, authenticated product view, RLS, pricing and persistence.
