# Upgrade 405 — Credit Backend Integration Readiness

Adds an authorized, read-only Supabase RPC and employee diagnostic view for a selected Credit payment draft. It reports invoice eligibility, identity-registry existence, pending request presence, and explicitly **unverified** authoritative balances, ownership/consent, and transactional debit integration. Credit payment eligibility remains **blocked** by design.

The existing `CREDIT_BACKEND_DESIGN.md` states the authoritative credit backend is not deployed. Do not infer real balance or credit limit from barcode registration. Next work requires inspecting the actual production schema and approval policy before implementing any financial write.

Tests not run: Flutter compile, Supabase migration, live authorization and financial reconciliation.
