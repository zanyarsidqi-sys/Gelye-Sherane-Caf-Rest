# Upgrade 249 — Legacy payment writer interlocks

## Actual changes
- Database BEFORE INSERT guards on six known payment/settlement tables; block new legacy postings for orders with immutable Admin-discounted invoice snapshots.
- Lock parent order row to serialize with invoice snapshot creation.
- Admin-only read-only RPC `gs_locked_discount_payment_guard_status(order_id)` shows trigger coverage.
- No physical payment capture, credit debit, printing, or final invoice settlement added.

## Important limits
- Other tables and direct UPDATE paths are not proven covered. Existing corrections/refunds require separate review.
- SQL migration has not been executed against a real Supabase instance; Flutter has not been compiled.
- Trigger installation deliberately fails if any required legacy payment table is missing; check deployment migration ordering.
- Code implementation for Tables remains estimated 94%; this is a financial hardening step, not verified readiness.
