# Upgrade 364 — Food draft employee review sign-off

- Adds an authorized, one-time, audited review of a guest-stay food-only draft.
- Review is blocked when orders are absent or ledger/order totals and delivery state disagree.
- The employee UI offers Review, and displays reviewed/changed-since-review status.
- A review is not an invoice, payment, accommodation charge, or settlement.
- Further orders can make the reviewed snapshot stale; status RPC identifies changed totals/counts.
- Pending: complete official invoice/payment schema mapping and reconciliation before posting.
- Flutter compilation and live Supabase migrations not executed in this environment.
