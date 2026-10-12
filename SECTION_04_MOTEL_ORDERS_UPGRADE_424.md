# Upgrade 424 — Enforce invoice binding at authorization request creation

Replaces the staff authorization-request RPC with a fail-closed invoice UUID check. The backend locks the invoice row, requires an existing unpaid motel food finance invoice, and requires the exact requested IQD amount to equal the invoice total before recording a request. The Flutter input now validates UUID syntax. Historical authorization requests are not retroactively validated. This does not verify identity or consent, authorize debit, or settle invoices. Flutter and live Supabase tests were not run.
