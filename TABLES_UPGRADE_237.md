# Upgrade 237 — Admin-only discount mode foundation

Adds an isolated, server-authorized configuration and audit ledger for table/motel discount modes. Admin UUIDs must be provisioned by trusted backend operations into `gs_cafe_discount_admins`; no user can self-register as an admin. Discount types: percentage (0–100) or fixed IQD per product; base mode normal/tourism/owner. Owner Mode is **not yet a priced checkout mode**; its configuration value is reserved only.

**Not implemented:** automatic discounted barcode pricing, owner prices, bill-finalization discounts, bill printing, preventing stacking in actual checkout, and UI. Existing `gs_create_cart_order` remains server-priced and unchanged. Never represent configured discounts as applied to financial transactions. Next upgrade should add an admin-only Flutter settings UI, then implement an atomic, audited backend pricing path with immutable price snapshots and explicit billing rules.

No Flutter compilation, Supabase migration execution, or device tests were performed. Review migration dependencies and deploy on staging first.
