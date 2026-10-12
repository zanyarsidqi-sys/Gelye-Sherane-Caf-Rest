# Dashboard Upgrade 31 — Payment review and cash reconciliation

- Added a read-only cash reconciliation screen accessed from the payment confirmation queue.
- Reads existing `gs_cash_reconciliation` RPC (migration 022), which checks payment-management permissions on the server.
- Shows order total, recorded cash payments, cash-only difference, and cash record count.
- Explicitly distinguishes cash-only difference from all-method outstanding balance.
- Pending credit and online submissions are NOT credited as received funds.
- Does not introduce unsafe client-side approval, rejection, refund, or credit debit operations.
- Receiver approval, duplicate-reference protection, atomic credit posting, evidence access, and approval audit still require backend implementation and verification.
- Flutter compilation, Supabase migration execution, and real device verification deferred.
