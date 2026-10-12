# Upgrade 549 — Kitchen revision exception investigation intake

- Adds permission-protected, auditable exception case intake with mandatory notes and server-side reconciliation validation.
- Prevents duplicate open cases for the same dispatch using a partial unique index and row lock.
- Adds a read-only case history RPC scoped to the table order and kitchen permissions.
- Flutter revision dialog shows open case count and allows staff to escalate inconsistent receipt records.
- No automatic modification to dispatch receipt, kitchen preparation, invoice, payment, or price records.
- Requires previous migrations including 546 and new migration 549.

Verification: ZIP integrity and static source assertions only. Flutter compilation and live Supabase tests not run.
