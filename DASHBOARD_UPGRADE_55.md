# Dashboard Upgrade 55 — Owner Guest Request Foundation

Added a permission-checked staff request RPC:
`gs_request_owner_guest_offer(visit_id, order_id, amount_iqd, reason)`.

- Verifies active table visit, matching non-motel order and order item total.
- Locks visit/order and prevents a second pending or verified request.
- Stores requested amount separately; complimentary applied amount stays ZERO.
- Records staff actor, reason and request audit.
- Does not modify any bill, revenue, payment or kitchen status.
- Does NOT mark a request Owner Verified. That requires actual owner account
  identity, step-up MFA, owner-only server approval, ledger and audit.

Draft only. No deployed migration or Flutter compilation. Existing legacy
functions, permission names, concurrent payment behavior, and SQL schema
compatibility must be reviewed before production.
