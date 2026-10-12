# Upgrade 1336: financial reference amount and motel source mapping safety

- Adds read-only, payments-management-permission-gated RPC `gs_financial_order_amount_motel_safety(p_order_id bigint)`.
- Counts verified external evidence with same-order amount mismatch, cross-order reference conflict, or no ledger reference; avoids join multiplication using EXISTS.
- Checks motel finance invoice UUID source bridge coverage and source fingerprint, room, session and amount mismatches.
- Reports legacy order bridge mapping separately; never infers mapping from a motel order flag.
- Payments Management adds per-order diagnostic dialog and timeout/validation. Dashboard guidance updated.
- **Not complete:** all-method canonical posting, package prepayment proof, Standing Cash and Pending Payment balances. No live verification claimed.
- Migration must be tested and deployed; it depends on pre-existing draft-founded tables. No payment mutation.
