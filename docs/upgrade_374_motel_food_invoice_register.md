# Upgrade 374 — Atomic food invoice register

- Adds a food-only invoice register and source-linked lines with uniqueness constraints.
- Employee posting requires both Motel Orders and Invoices & Payments edit permissions.
- Revalidates review fingerprints, guest room, full source reservation equality and amounts under guest-stay lock.
- Posting is atomic; retry returns the same invoice only if all underlying lines still match.
- Read-only listing RPC requires both view permissions.
- Does NOT modify the legacy official invoice tables, ledger invoice_id, cash, payments, or credit balances.
- Deployment and integration tests not run. Apply migrations in order and test on staging first.
