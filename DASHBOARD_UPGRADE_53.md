# Dashboard Upgrade 53 — Visit-linked payment reconciliation

Added `20261009_054_visit_cash_reconciliation_draft.sql`.

- Read-only per-visit, per-order cash ledger reconciliation.
- Checks server-side view permissions and visit existence.
- Returns order total, recorded cash, cash remaining and explicit status.
- Never calls an order 'fully settled' based on cash alone when other
  methods (card, credit, online or owner offers) might exist.
- No automatic backfill of historical orders or modification of payments.
- Does not alter the existing cashier collection function or table release.
- Not a production checkout gate; no unified settlement ledger exists yet.

Critical pending: verified noncash/credit settlement, idempotent transaction
references across payment types, approved owner waivers, visit-specific
checkout/cleaning, migrations compatibility review, tests and deployment.
