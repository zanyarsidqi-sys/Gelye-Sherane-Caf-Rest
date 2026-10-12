# Dashboard coding upgrade 08 — receiver payment confirmation

Added `lib/screens/dashboard/payment_confirmation_panel.dart`, a safe read-only confirmation queue UI for credit and online payments. It requires authentication, reads through `gs_pending_payment_confirmations`, fails closed if that RPC is unavailable, and deliberately provides no local 'approve' action.

## Backend work required before enabling confirmations
- Create RLS-protected payment requests with status `pending`, amount IQD, order, method, submitter, screenshot evidence storage path (private bucket), provider transaction reference and timestamp.
- Require a separately authorized receiver; prohibit self-approval; confirm actual receipt via provider/bank before approving.
- Implement a single atomic, idempotent server transaction to approve a request, create a ledger entry and, for credit, debit the account exactly once with balance/limit checks.
- Enforce duplicate-reference detection, audited rejections, no negative credit balance unless policy explicitly allows, and split-payment outstanding balance constraints.
- Expose an authorized RPC `gs_pending_payment_confirmations` with restricted fields; wire its screen into Dashboard after permissions and database contracts are available.
- Never treat uploaded screenshot as proof of receipt or count pending payments as collected funds.

No compilation, Supabase migrations, RPC verification or payment-provider testing performed. Overall project completion estimate remains ~54% (historical, unverified).
