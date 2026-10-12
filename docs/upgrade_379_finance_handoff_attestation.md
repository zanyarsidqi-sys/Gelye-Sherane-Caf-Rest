# Upgrade 379 — Finance Handoff Attestation

Adds a finance-side action for an authorized employee to attest the source-verified motel food invoice register with a mandatory note. The database rechecks the existing line audit and records a deterministic fingerprint of each linked order, ledger, reservation, and amount. Repeated requests do not create duplicate attestations; changed source fingerprints are blocked for manual reconciliation. No unified invoice, payment, or credit deduction is created.

Deployment: apply migration `20261010_379_motel_food_finance_handoff_attestation.sql` after migration 378. Run Flutter analysis and live Supabase tests before production. The existing food-only invoice register remains separate from unified invoices.
