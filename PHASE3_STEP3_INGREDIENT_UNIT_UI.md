# Phase 3 — Ingredient Unit Configuration UI

Menu > Configure ingredient stock units opens a searchable-by-scrolling active product list and shows configured units. An authorized employee may set piece, gram, or milliliter via the gs_set_inventory_unit RPC from migration 030. The server refuses unsafe relabeling of existing quantities or recipes. The UI does not silently convert quantities.

Deployment: apply migrations through 030 in order, log in with menu and products_inventory access, set units for recipe ingredients, verify the UI refreshes, and attempt an unsafe change to confirm server rejection. Requires live Supabase testing and Flutter compilation; neither has been completed here.
