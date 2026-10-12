# Upgrade 422 — Authorization Request Cancellation

Added authorized cancellation of pending customer credit authorization requests, with mandatory reason, cancelling employee ID and timestamp. Read-only v2 listing exposes cancellation history without changing the old RPC return signature. The employee interface can cancel a request and see its audit details.

**Important:** This is not customer-facing consent confirmation. Customer identity/consent infrastructure is still missing, so no consent or credit debit can safely be accepted. Financial processing remains blocked.

Migration `20261010_422_credit_authorization_cancellation.sql`. Flutter compilation and live Supabase migrations not tested.
