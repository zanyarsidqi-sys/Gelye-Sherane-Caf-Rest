# Phase 1 Step 5 — Migration safety inventory: Rest

Static source inspection only. No migration executed and no live Supabase project inspected.

- Migration files: **475**
- Duplicate migration timestamp prefixes: **3**
- Potential destructive SQL matches (not verified as executable): **2**
- Inventory SHA-256: `bb02b7cc4902a34b1145508eda65e6345157aae845c2f62a0ab9302fa722f278`

## Duplicate timestamp prefixes (review before CLI deployment)

- `20261009`: `20261009_001_phase3_order_foundation.sql`, `20261009_002_kitchen_status.sql`, `20261009_003_menu_product_admin.sql`, `20261009_004_menu_product_edit.sql`, `20261009_005_website_settings.sql`
- `20261010`: `20261010_1142_kitchen_served_item_integrity.sql`, `20261010_1143_kitchen_served_item_row_locks.sql`, `20261010_1144_kitchen_served_item_immutability.sql`, `20261010_151_reservation_aware_table_seating.sql`, `20261010_152_reservation_checkin.sql`
- `20261011`: `20261011_1170_kitchen_terminal_order_item_immutability.sql`, `20261011_1174_kitchen_item_station_labels.sql`, `20261011_1175_kitchen_required_acceptance_eta.sql`, `20261011_1176_kitchen_completed_history.sql`, `20261011_1177_kitchen_status_audit.sql`

## Potentially destructive SQL text matches (manual review needed)

- `20261010_371_motel_food_invoice_source_reservations.sql`: TRUNCATE
- `20261010_374_motel_food_invoice_register.sql`: TRUNCATE

## Safe deployment checklist

1. Create a separate Supabase project for this app; do not reuse production credentials or data from the other café.
2. Obtain an encrypted, tested database backup and restore point before any migration.
3. Check migration filenames/version format and timestamp collisions; fix with an explicit migration mapping, not blind renaming.
4. Review SQL dependencies, ownership, RLS policies, grants, SECURITY DEFINER functions, and migration ordering manually.
5. Run migrations against a fresh disposable staging project; inspect errors and schema differences.
6. Run auth/MFA/RLS cross-account tests, and test both delivery/pickup and restaurant workflows as applicable.
7. Deploy to production only after review, backups, and explicit approval.

Do not apply all migrations blindly. This inventory is not a dependency graph or proof of deployability.
