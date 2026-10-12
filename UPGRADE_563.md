# Upgrade 563 — Replacement response reconciliation guard

Source: complete Upgrade 562 archive. Section 03 Table Orders.

The Flutter client now validates the committed order-item identity, replacement product identity and integer financial difference against the server quotation before showing a success amount. If the RPC returns an unexpected shape or delta, the UI warns that the transaction may have committed and requires checking refreshed order history before retrying. The existing finally block refreshes the board.

No SQL migration is required. No claim is made that the server transaction rolls back after a malformed response; it may already be committed.

Verification: static source assertions and ZIP CRC verification only. Flutter compilation, Supabase deployment and live transaction tests not performed.
