# Phase 3 Step 2 — Product selection reliability

- Barcode scanning no longer replaces the cached 200-product catalog with a one-item result.
- Added local filtering of the loaded product catalog by name or barcode.
- A scanned product outside the first 200 remains selectable without changing the server-side price calculation.
- Refresh clears the selected table as well as the selected product to avoid using a stale destination.
- No SQL migration needed for this update.

## Limitations and verification

- Catalog filter only searches the first 200 loaded products; barcode lookup searches the database directly.
- Existing order creation is still single-product per order; multi-item atomic checkout is not implemented.
- Flutter compilation, device testing, live database tests, and all 35 section verifications remain outstanding.
- Overall historical implementation estimate remains 60% until a requirement-by-requirement audit.
