# Upgrade 411 — Credit Integration Requirements & Migration Repair

**Existing project inspection:** `lib/sections/credit_management.dart` currently uses a local-only `CreditBarcodePanel` and does not implement an authoritative customer credit ledger. Accordingly, no real ownership, balance, limit, consent, or debit integration can be claimed.

**Upgrade:** New permission-gated `gs_staff_motel_credit_integration_requirements()` RPC provides a server-side fail-closed integration checklist for the future credit system. Every missing capability is explicitly marked `not_implemented` and settlement is `blocked`.

**Migration repair:** Fixed migration 404's PostgreSQL return-type incompatibility: Upgrade 403 defined `gs_staff_list_motel_credit_verifications(uuid)` with six output columns, whereas 404 expanded it to nine. PostgreSQL cannot `CREATE OR REPLACE` a function with a different return type. Migration 404 now drops that specific old function before recreating it. If Upgrade 404 was already applied through a manual workaround, review migration history before rerunning.

**Safety:** No credit account data, balance or debit is created or changed. All existing functions remain, except for the necessary signature recreation in migration 404. Migration SQL and Flutter were not run against a live backend.
