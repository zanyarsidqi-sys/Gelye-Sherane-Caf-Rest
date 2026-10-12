# Upgrade 383 — Dedicated finance invoice posting

Added transaction-safe, source-linked posting from a verified finance intake draft to dedicated `gs_motel_food_finance_invoices` and immutable line records. Requires Motel Orders view and Invoices & Payments edit permissions, checks intake integrity and line totals, locks intake to serialize posting, and verifies exact source identity for idempotent retries. Added an employee confirmation action in the Finance Handoff panel.

**Scope limitation:** This is a dedicated motel-food finance invoice register, not the existing unified accounting invoice table. Payment remains unpaid. No cash, credit, electronic payment, accommodation charge, or existing payment table is modified.

**Verification:** Archive integrity checked; Flutter CLI and live Supabase database unavailable. Apply migrations in order and test with real authenticated roles before production use.

Section 04 progress: 83% estimated, not production verified.
