# Upgrade 1464: cross-method exclusivity

Independent changes: (1) credit RPC refuses invoices with prepaid allocations; (2) direct credit-journal invoice-link trigger refuses prepaid allocations; (3) prepaid RPC refuses historical unlinked credit charges; (4) runnable read-only collision audit detects credit/prepaid, cash/prepaid, and historical-credit/prepaid overlaps.

All three posting paths lock the invoice row before their collision checks. No provider verification, numeric cafe-order mapping, invoice-paid transition, unified ledger posting, or certified Dashboard IQD is claimed.

Deployment: back up staging, apply all migrations in sequence, run `supabase/diagnostics/cross_method_collision_audit_1464.sql`, then run approved test-fixture transactions with two separate DB sessions and confirm no double-post and full rollback. Test credit-before-prepaid, prepaid-before-credit, direct journal insertion, same-request retry, concurrent opposite methods, invalid receipt, and preexisting historical unlinked charge. **Do not run financial writes on production for testing.**

No live staging connection or Flutter SDK is available in this environment.
