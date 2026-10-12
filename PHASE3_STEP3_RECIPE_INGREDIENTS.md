# Phase 3 Step 3 — Recipe ingredient deduction (migration 029)

- New permission-checked RPCs: `gs_recipe_components(menu_product_id)` and `gs_recipe_set_component(menu_product_id, ingredient_product_id, quantity)`.
- `quantity=0` removes a component. Positive quantities are integer units of stock; standardize units (grams, milliliters, pieces) before rollout.
- On transition to `served`, menu items with recipes deduct the listed ingredient products; items without recipes retain direct finished-product deduction if tracked.
- All deductions, stock movement rows, and kitchen status update are in one database transaction. Missing inventory rows for recipe ingredients or insufficient quantities reject the status transition.
- Caveat: recipes are not yet editable through Flutter UI; configure using authenticated RPC calls. This migration does not backfill historical orders, reserve stock on order placement, or handle returns/refunds.
- Required tests: recipe with multiple ingredients, multiple orders, insufficient stock rollback, concurrent serving, mixed direct/recipe items, re-serving, employee permission denial and stock unit consistency.
- Deploy after migration 028 in staging first. Flutter compile and live Supabase tests have not been run.
