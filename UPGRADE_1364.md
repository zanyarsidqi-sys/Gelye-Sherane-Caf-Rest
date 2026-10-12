# Upgrade 1364 — Recorded payment metadata filters and draft details

- Adds an exact-match creator employee ID filter for payment preparation drafts using only `created_by` when returned by the authorized RPC.
- Dynamically offers payment subtype values only when `payment_subtype` is actually returned; no invented cash/credit categories.
- Allows tapping draft rows to inspect a restricted, read-only set of recorded metadata. No new settlement, print, or export path.
- Existing bottom-of-list total continues to use `visiblePaymentDrafts`.
- Linked sections review: motel payment drafts and posted invoices use separate source records; Standing Cash, online delivery and unified Payments require later dedicated integration.
- Verify with real Supabase schema, permissions and Flutter compilation before production.
