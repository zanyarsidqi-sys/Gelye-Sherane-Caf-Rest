# Upgrade 366 — Audited food draft re-review

- Adds a controlled re-review action when a signed-off food draft changes.
- Requires a reason, Motel Orders edit permission, guest-stay locking, delivered-order completeness, and ledger/line-item consistency.
- Stores the prior review in append-only review history before replacing its snapshot.
- Disables re-review when the draft is blocked and refuses unnecessary re-reviews.
- No official invoice, payment, or credit deduction is created.

Verification: ZIP integrity and structural checks only. Flutter compilation and live Supabase migrations were not run. Section 04 remains approximately 72% complete (estimate).
