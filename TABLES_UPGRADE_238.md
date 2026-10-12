# Upgrade 238 — Admin Discount Mode Flutter UI

- Adds an Admin Discount Mode dialog to Tables Management.
- Admin can select Table or Motel, destination reference, Normal/Tourism/Owner base mode, percentage or fixed-IQD discount, and active status.
- Loads saved configurations and permits selecting an existing configuration for editing.
- Calls `gs_list_cafe_discount_modes` and `gs_set_cafe_discount_mode` from Upgrade 237. Authorization is enforced server-side; non-admin users see a permission error and cannot save.
- Existing backend audit records all changes. No new migration required.
- IMPORTANT: This config screen does not yet apply discounts during barcode scanning or bill printing. Owner-specific item prices also remain pending.
- No Flutter build, Supabase integration test, or physical POS testing performed.
