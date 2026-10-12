# Upgrade 484 — Permission-scoped cash collections

Adds a read-only dashboard view of two **separate** cash ledgers: legacy table-order cash receipts and UUID motel-food cash settlements. Figures are Iraq-local-day, independently permission-gated, and omitted when access is missing. The UI never combines these into revenue, profit, or a reconciled financial total. No credit charging or payment mutation was added.

## Required validation
- Apply migration 484 after preceding migrations.
- Test unauthorized Dashboard users, Dashboard-only users, finance-only users, and authorized cross-section users.
- Compare each result with the source ledger using Baghdad-day boundaries.
- Confirm ledger reconciliation and cash refunds/corrections before interpreting collections as business income.
- Run Flutter analyze and device testing (not performed here).

Section 01 remains 83% provisional until accounting integration and tests are completed.
