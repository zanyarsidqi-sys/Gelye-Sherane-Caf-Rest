# Upgrade 1471: motel prepaid settlement journal

Adds an atomic, idempotent, append-only motel-only journal for an already allocated provider-verified receipt. No café order ID is inferred from a motel UUID. This is NOT the unified payment ledger and does NOT change invoice payment_status, certify dashboard totals, or verify external provider payments.

Apply migrations in order to an isolated staging database, then run diagnostics/motel_prepaid_settlement_smoke_1471.sql. For transaction tests seed an actual eligible motel invoice with matching lines, a provider-attested receipt and allocation using approved test fixtures, call RPC twice with authenticated authorized context, confirm one journal row, then test mismatched evidence and rollback. Do not use production payment credentials. Rollback migration only if no journal rows exist; preserve financial history otherwise.
