# Dashboard Upgrade 78 — Owner Guest Financial Readiness

Added a read-only financial preflight RPC, `gs_owner_guest_financial_readiness`.
It checks the owner MFA review record, approved amount snapshot, current owner
provisioning, order/visit linkage, order total, existing payment records, and
competing offers. It returns a specific blocker for the next required action.

**Critical limitation:** `waiver_posted=false` and `posting_permitted=false`
are intentional. This does not create a complimentary credit, does not mark
an offer as Owner Verified, and does not alter revenue, payment status, or
customer debt. AAL2 session MFA alone does not establish fresh owner step-up.

To enable genuine complimentary billing, implement and test authoritative
per-item settlement allocations, a fresh owner verification mechanism, a
transactionally posted immutable waiver ledger, idempotency, audit, and
correct treatment of paid or partially paid orders. Test on Supabase staging.

No Flutter compilation, database migration execution or production testing.
