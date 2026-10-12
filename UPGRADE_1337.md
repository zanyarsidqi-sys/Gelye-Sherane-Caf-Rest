# Upgrade 1337 — Finance iPhone parity and safe inspection navigation

- Replaced five trailing reconciliation icons per cash-order row with one responsive Flutter PopupMenuButton. This prevents the narrow iPhone ListTile trailing row from overflowing while preserving all five original inspection callbacks, their existing Supabase RPC authorization and their error handling.
- Disabled the menu for invalid order identifiers.
- Updated Dashboard live-unpaid-card source comments to state that the actual Flutter metric widgets, not a simulated UI, are the design source of truth.
- No settlement values are fabricated; neither Standing Cash nor Pending Payment is certified by this change.
- No database schema changes or payment posting changes.
- Flutter runtime screenshot comparison and compilation not available in this environment; exact visual parity is not verified.
