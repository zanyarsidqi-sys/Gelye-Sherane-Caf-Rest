# Dashboard Upgrade 102 — Idempotent Correction Posting Intent (DRAFT)

Added a private, RLS-protected `gs_cash_correction_posting_intents` table and
`gs_prepare_cash_correction_posting_intent(request_id, intent_key)` RPC.

- Requires an authenticated employee with invoice/payment edit permission.
- Locks the pending correction request to serialize competing attempts.
- Requires an independent finance approval with the exact amount snapshot.
- Validates the original receipt and order and rejects conflicting requests.
- Stores a unique request/review/idempotency key; same-key retry returns
  the same intent and a different key for the same request is rejected.
- Does not change a cash receipt, customer balance, payment ledger, or table.

**Important:** This is preparation only, not actual financial posting.
Posting requires verified funds, accounting allocation, refund handling,
ledger reconciliation and audited transactional execution. The existing
settlement and bill-transfer gates remain disabled.

Verification: ZIP CRC and structural checks only. No Supabase deployment,
PostgreSQL execution, Flutter compilation, or device tests.
