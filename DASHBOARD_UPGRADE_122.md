# Dashboard Upgrade 122 — Finance attestation action in Flutter

**Actual UI-to-database integration:** the existing Dashboard Cash Reconciliation
order detail now has an **Attest cash-only settlement** action. The employee
must explicitly confirm the independent review before Flutter calls
`gs_attest_cash_only_order_settlement(p_order_id)` (Upgrade 113).

The backend remains authoritative: it requires provisioned finance reviewer,
MFA AAL2, exact cash receipt total, and separation from the cash collector;
it rejects mixed, corrected, externally paid, transferred and owner-offer
orders. Errors do not falsely claim a successful attestation. The action
refreshes reconciliation after success.

This does **not** refund money or release a table. A separate authorized
reviewer must use the checkout operation after guest departure and cleaning.

**Not tested:** Flutter compilation, Supabase deployment, live MFA sessions,
concurrent cash posting, and finance workflow end-to-end. ZIP CRC verified.
