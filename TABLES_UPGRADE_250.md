# Upgrade 250 — Legacy payment mutation protection

## Implemented
- BEFORE UPDATE/DELETE guards for six known payment and settlement tables, complementing Upgrade 249 INSERT guards.
- Blocks mutation of payment rows belonging to a locked discounted invoice, including moving a row into or out of such an order.
- Locks referenced parent orders in deterministic order to reduce concurrent reassignments and races.
- Expands Admin-only read-only guard diagnostics to report INSERT and UPDATE/DELETE coverage separately.

## Important limits
- No cash collection, credit debit, mixed settlement, invoice printing, or hardware integration is enabled.
- No live Supabase migration, SQL execution, Flutter compilation, or end-to-end tests performed.
- The diagnostic verifies presence of named triggers, not complete protection of every possible writer.
- Triggers protect ordinary DML; privileged database owners can still bypass or disable triggers.
- Preexisting records, out-of-band providers, and other tables still require audit before settlement.
- Tables code implementation remains estimated at 94%; Customers paused at 45%.
