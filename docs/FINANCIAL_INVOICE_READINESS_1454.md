# Upgrade 1454: exact changes and deployment gate

1. Added invoice-scoped read-only source reconciliation RPC.
2. Checks invoice source-line count and amount.
3. Checks source bridge fingerprint, room, guest, amount and absence of fabricated numeric ID.
4. Counts actual motel cash receipts and checks paid_cash status consistency.
5. Counts journal credit charges by source request and draft invoice relationship.
6. Detects cash/credit collisions.
7. Counts active crosswalk candidates without treating them as verified identity.
8. Includes draft count for mixed-method investigations.
9. Restricts RPC to authenticated motel and finance viewers.
10. Explicitly refuses prepaid, unified ledger and Dashboard IQD certification.
11. Adds 20 runnable archive/source regression assertions.

These are checks in one read-only reporting function, NOT eleven separately completed settlement features.

## Staging gate
Run migrations in order on a disposable Supabase staging clone. Test permissions with an actual JWT, invoices with no lines, reconciled lines, a real paid_cash receipt, credit-only journal, cash/credit collision, conflicting crosswalk evidence, concurrent charges and rollback. Verify `gs_financial_invoice_settlement_readiness` reports the real source counts and never returns a certified IQD amount. Do not enable production credit settlement before this gate.
