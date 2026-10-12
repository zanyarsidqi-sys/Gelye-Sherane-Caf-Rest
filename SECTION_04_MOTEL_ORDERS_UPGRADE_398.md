# Upgrade 398 — Cash Receipt Attestation

Adds an authorized, idempotent cash-received acknowledgement to an existing cashier review. Requires unique receipt reference, records cashier/time/note, and blocks draft cancellation after cash acknowledgement. Acknowledgement is **not** shared ledger settlement and does not change invoice payment status.

Apply migration `20261010_398_motel_cash_receipt_attestation.sql` before using UI.

No Flutter compile or live Supabase verification performed. Estimated Section 04 progress: 87%.
