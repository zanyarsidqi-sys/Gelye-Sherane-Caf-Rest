# Dashboard Upgrade 83 — Reconciliation Integrity Guards

**Actual SQL change:** Three database triggers now protect reconciliation data:

1. Before a trusted process links a cash receipt to a unified-ledger entry, validate identical order and amount, cash credit direction, and `legacy_cash` source.
2. Reject updates or deletion of existing crosswalk links.
3. Reject updates or deletion of either underlying receipt or ledger entry after a link has been established.

These controls reduce accidental corruption and crosswalk mismatches; they **do not** establish that a cash payment was genuinely received. There is no client-facing link creation permission and no new payment-posting RPC.

**Known limitation:** Immutable reconciled records need a separately designed correction/reversal workflow. PostgreSQL and Flutter builds were not executed; SQL syntax and schema compatibility require staging verification. Bill transfer execution remains disabled.
