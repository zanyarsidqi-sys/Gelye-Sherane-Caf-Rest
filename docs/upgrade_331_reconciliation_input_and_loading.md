# Upgrade 331 — reconciliation input and in-flight safety

- Fixed a stuck loading state when staff edits the order ID during a pending RPC.
- The generation guard still rejects stale responses from the old order ID.
- Restricts order ID entry to digits (18 characters maximum).
- Rejects negative gross order, recorded cash, mirrored cash, unlinked cash, and exception counts.
- Does not change settlement, transfer, refund, or payment authorization.

Validation: ZIP integrity and static source checks only. Flutter CLI and live Supabase testing unavailable.
