# Upgrade 403 — Credit Verification Request Workflow
Creates permission-gated, auditable **pending** credit verification requests for active registered barcodes and unpaid motel-food credit drafts. Locks the draft and invoice during request creation, ensures one pending request per draft, and returns the existing matching request for repeated calls. Adds a staff action to initiate a request without persisting the barcode in Flutter.

**Not implemented:** Actual account ownership verification, authoritative credit balances/limits, customer consent, debit reservation, credit deduction, or paid status. Do not treat a pending request as payment approval. Live Supabase and Flutter compilation not run.
