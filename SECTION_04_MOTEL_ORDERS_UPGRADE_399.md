# Upgrade 399 — Motel Cash Settlement

Introduces a UUID-native **motel-food-only** cash settlement table and transaction-safe authorized settlement RPC. Requires existing physical cash receipt acknowledgement, matching invoice, source reconciliation, and finance permissions. Uses invoice row locking and unique constraints to ensure at-most-once settlement; repeated calls for the same intent return the existing settlement. Updates finance invoice `payment_status` to `paid_cash` atomically.

Adds employee **Settle Cash** action with explicit confirmation and settlement receipt details.

**Scope:** This is a dedicated motel-food ledger, NOT the existing shared numeric-order accounting ledger. Credit, electronic payments, shared accounting integration, refunds and reversals remain unimplemented. Do not deploy to production before testing migrations and accounting reconciliation. Flutter compilation and live Supabase migration were not executed.
