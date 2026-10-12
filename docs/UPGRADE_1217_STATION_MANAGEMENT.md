# Upgrade 1217 — station management and inventory mapping

Added station management tab to Kitchen and product-to-station mapping tab to Products & Inventory. Uses existing `gs_set_product_preparation_station` for authorized mapping and preserves historical ticket routing. Station employee restrictions continue to be enforced by `gs_can_work_station` and scoped ticket RPCs from Upgrade 1189.

**Safety limitation:** Existing station schema requires a valid configured printer/POS on creation. This upgrade supports renaming and deactivation of existing configured stations, but does not offer an unsafe one-click creation that bypasses device provisioning. Create new stations using the existing `gs_set_preparation_station` device-aware RPC until a dedicated wizard is implemented. Verify remaining read RPCs and all UI surfaces for station isolation before production.

No Flutter compilation, migration deployment or live Supabase testing was performed.
