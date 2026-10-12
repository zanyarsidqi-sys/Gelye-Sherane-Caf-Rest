# Upgrade 329 — staff payment reconciliation diagnostic

Added a seventh Table Orders tab for authorized staff to query the existing `gs_dashboard_payment_reconciliation_summary(p_order_id)` RPC. It requires finance view permission on the server and does not expose finance data to public customer QR sessions.

The existing RPC reports legacy cash, matched mirror entries, non-mirrored ledger entries, exceptions and a provisional remaining amount. **It does not certify settlement or account for every possible external/credit/discount source.** The screen intentionally never presents a final customer payable balance or allows payment mutations.

Integration checks still required: deploy migrations; test finance vs non-finance employees; reconcile mixed payments, discounts, refunds, transfers and credit; run Flutter analyzer and live Supabase tests.
