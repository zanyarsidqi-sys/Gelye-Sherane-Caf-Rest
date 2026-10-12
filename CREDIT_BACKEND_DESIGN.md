# Phase 3: Barcode Credit Payment — backend contract (NOT deployed)

## Status
Frontend has a local draft-review form. **No balance changes, account lookup, withdrawal submission or payment posting is active.** This update adds a read-only Supabase inspection query and an implementation contract only. Do not run a schema migration until existing tables, policies and approval rules are reviewed.

## Both order types
1. Cashier selects Credit on Table or Motel checkout.
2. Scan/enter customer barcode. Server resolves one active customer credit account. Barcode is an identifier, not proof of permission.
3. Display masked customer identity, credit type, available balance, credit limit, outstanding debt and payment amount. Never show another customer's data to unauthorized staff.
4. The amount must be derived on the server from order items and previously posted payments, not from an editable Flutter field. Motel order pricing must remain Tourism.
5. Request is created with immutable order ID, account ID, actor ID, amount, currency IQD, creation time, unique idempotency key and status `pending`.
6. Approval policy **UNDECIDED**: until confirmed, default to manager approval before posting a debit. The server must check active account, employee permissions, remaining credit, order ownership/status, and outstanding amount.
7. On approval, perform the debit and payment posting **in one database transaction**, with row locks and a unique constraint on the idempotency key. Prevent duplicate payments against the same order and prohibit overdrafts beyond authorized credit limits.
8. Rejections and cancellations must never deduct credit. Reversals require a separate, audited compensating entry; never delete posted ledger entries.
9. Maintain append-only audit trail and immutable ledger entries; reconciliation reports distinguish requested, approved, posted, rejected and reversed states.

## Security rules
- RLS on customer accounts, requests and ledger. No direct client inserts/updates to balances or ledger.
- Authenticated, role-checked SECURITY DEFINER RPCs with fixed search_path, explicit grants and audit entries.
- Do not store sensitive barcode data in plaintext logs. Do not expose credit details in error messages.
- Account lookup and debit must not be performed in local-only Flutter code.

## Tests to run tomorrow
- Valid account, invalid barcode, inactive account, insufficient credit.
- Cashier forbidden from approving when manager approval is required.
- Same request submitted twice; two cashiers concurrently paying the same order.
- Price mode: Motel always Tourism; table price based on saved order mode.
- Offline/retry, network timeout after successful posting, reversal and reconciliation.
- RLS: unauthorized staff cannot list customers or view unrelated balances.

## Next prerequisite
Run `supabase/verification/credit_backend_readiness.sql` (read-only) and review the results. Confirm whether credit debits require manager approval or are auto-approved within limits. Then create a migration tailored to the existing schema and test in staging before production.
