# Dashboard Upgrade 99 — Cash receipt correction requests

Added a protected request table and a permission-checked RPC for employees to
request corrections to recorded cash receipts. The request captures original
receipt/order, signed proposed adjustment in IQD, reason, employee, timestamp,
and an idempotency UUID. Only one pending request per receipt is allowed.

**Safety:** The original receipt remains immutable; creating a request never
changes financial totals, creates a refund, marks a payment verified, or releases
a table. No correction-approval or posting endpoint exists yet.

**Outstanding:** implement owner/finance review with segregation of duties,
trusted cash refund/adjustment ledger posting, correction settlement, audit
trail, staging database migrations and concurrency tests. The ZIP integrity
check does not validate PostgreSQL compilation or Supabase RLS behavior.
