# Phase 3 Step 3 — Inventory low-stock alert overview

The live Products & Inventory screen now provides counts of tracked products, low-stock products and out-of-stock products, with quick filters. These are calculated from the permission-controlled `gs_inventory_overview` response; no new table or migration is required. Refresh fetches updated values.

## Verification required

Deploy migrations 001–028 in correct dependency order; log in with an authorized inventory employee; check zero quantity, at/below minimum and above minimum; adjust stock and refresh; verify access is denied without permission. This is an in-app alert overview, **not** push notifications, scheduled monitoring, or ingredient-level recipe deduction. Flutter compile and Supabase integration are not verified.
