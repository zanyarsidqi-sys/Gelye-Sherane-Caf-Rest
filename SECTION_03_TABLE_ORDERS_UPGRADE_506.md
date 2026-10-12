# Upgrade 506 — Table Orders action-priority queue

- Added **Needs action first** sorting on the existing permission-scoped fulfillment board.
- Order items sort by operational stage (pending acceptance, accepted, preparing, prepared, picked up, delivered), then by original creation time and item ID.
- Added visible counts for pending acceptance, preparing, and ready-for-pickup items, based only on the currently authorized and filtered records.
- No database schema, RPC permissions, or order mutation semantics changed.
- This is presentation-only prioritization, not automated kitchen dispatch.

Verification: ZIP structural validation only; Flutter compilation and live Supabase testing are outstanding.
