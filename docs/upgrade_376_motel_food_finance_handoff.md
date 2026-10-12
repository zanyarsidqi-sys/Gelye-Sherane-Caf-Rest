# Upgrade 376 — Finance handoff visibility

Added a read-only, permission-checked view of posted motel food-only register entries inside the existing Invoices & Payments screen. Reconciles source line counts and totals; mismatches display Requires reconciliation. No unified invoice, cash posting, payment allocation, or credit debit occurs. The finance module's existing Payment Review panel is preserved. Requires applying migration 20261010_376_motel_food_finance_handoff.sql.

Testing: static code and ZIP validation only; Flutter CLI and live Supabase integration not available here. Section 04 estimated progress remains 79%.
