# Phase 3 Batch 9 — Live order submission UI

- Table Orders and Motel Orders now have an opt-in **Create a REAL Supabase order** switch.
- A product dropdown loads active products from `gs_menu_products`; user enters destination and quantity.
- Normal mode is default for tables; motel orders force tourism mode.
- Submission calls `SecureOrderService` and `gs_create_order` RPC, which selects the price server-side and checks `can_create` permission.
- Errors are shown; successful submission returns the server order ID.
- Existing local previews and read-only live history remain.
- **Do not activate before reviewing the optional SQL migration and verifying the existing permission schema.** No production database changes have been applied.
- No product administration, payment, kitchen status updates, or offline queue yet.
- Not compiled or tested on Windows. Archive-only checks performed.
- Progress estimate: 22%; 0/35 sections production-verified.
