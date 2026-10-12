# Upgrade 391 — Payment Draft Audit History

Adds an authenticated, permission-checked, read-only payment draft history RPC and an employee action in Invoices & Payments. Displays all draft attempts for a selected motel food finance invoice, including cancelled attempts, creator, timestamps and cancellation reasons. No payment posting, cash receipt, credit debit or electronic settlement.

Migration: `20261010_391_motel_payment_draft_history.sql`. Apply after migration 390.

Verification: ZIP structure only; Flutter compilation and live Supabase testing not performed. Section 04 progress estimate remains 82%.
