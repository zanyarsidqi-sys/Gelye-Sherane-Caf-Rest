# Upgrade 239 — Atomic cart barcode discount pricing

- Replaces server-side `gs_create_cart_order` to apply Admin-configured discount at order creation (same product barcode and ID).
- Table/motel scope, fixed IQD per unit or percentage, normal/tourism/owner base price, capped discount and immutable line price snapshots.
- Adds optional `owner_price_iqd` to menu products; owner mode fails closed if a product has no configured owner price.
- Adds original price, discount-per-unit and discount configuration reference to order items. Server ignores client price claims.
- Existing historical orders remain unchanged; newly created orders use the currently active Admin discount config.
- The existing cart barcode UI already uses `gs_create_cart_order`, so no client-supplied price is required.
- NOT IMPLEMENTED: Admin bill-level discount during printing, Owner price editing UI, physical printing, offline synchronization.
- IMPORTANT: Single-product order RPCs and public ordering flows are not yet migrated to this pricing rule; use the atomic cart workflow for this functionality until all routes are secured.
- Migration not executed against a live Supabase instance; Flutter build and integration tests not run.
