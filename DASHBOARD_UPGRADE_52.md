# Dashboard Upgrade 52 — Secure Table Visit Opening (DRAFT)

Added `gs_open_cafe_table_visit` RPC with:
- Active user and table-edit permission checks.
- Row lock on selected table and validation of capacity/occupancy/cleaning.
- Duplicate open-visit rejection; partial unique index from migration 051.
- Atomic visit creation and occupancy/guest count/tourism-mode update.
- Attempted safeguard by revoking legacy occupancy RPC execution.

**Do not deploy yet:** This RPC does not check future reservation holds,
other legacy order/occupancy functions can bypass the visit model, and revoking
the old table RPC would break existing edit/release flows until replacements
are implemented. It also needs integration with table UI, immutable audit,
visit-specific checkout, cash/card/credit settlement, and table transfer.

No Flutter build or Supabase integration test performed. Phase 3 historical
estimate remains approximately 54%, not verified.
