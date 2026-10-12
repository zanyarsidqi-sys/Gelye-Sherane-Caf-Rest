# Upgrade 361 — Motel food invoice integration preflight

Added staff-only, read-only `gs_staff_motel_food_invoice_preflight()` and employee screen readiness summary. Checks delivery timestamp, order/line/ledger totals, unpaid status, and existing invoice reference. Existing ledger `check(invoice_id is null)` is intentionally preserved. No official invoice, payment, credit deduction, or room charge is posted. Future integration requires a verified accommodation invoice model and idempotent financial posting contract.

Estimated Section 04 progress: 67%. Flutter and live Supabase tests not run.
