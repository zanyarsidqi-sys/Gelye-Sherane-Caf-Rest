# Upgrade 429 — Cross-Review Invoice Authorization Conflict Guard

Adds a database trigger with transaction-scoped advisory locking to prevent two simultaneously outstanding, unexpired customer authorization requests for the same motel-food invoice, even across different credit identity reviews. Also adds a permission-gated read-only conflict listing and an **Invoice Requests** action in the employee interface.

This is not customer consent. Credit debit remains disabled. Existing duplicate historical requests are reported, not silently deleted. The trigger assumes migration 425 has already introduced `expires_at`. Flutter compilation and live Supabase execution were not available.
