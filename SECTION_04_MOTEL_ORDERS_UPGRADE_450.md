# Upgrade 450 — Verified Identity Activation Guard

Introduces a database trigger that rejects new or updated **verified** customer authentication bindings until an authoritative identity verification workflow exists. The guard also rejects new/updated non-revoked bindings where the customer has raised an onboarding safety hold. Revocation remains possible. A read-only, permission-controlled staff RPC explains activation readiness and explicitly marks payment blocked.

This is a deliberate security improvement, not activation of customer consent, credit payments, or identity verification. Requires Supabase migration deployment and integration tests before production. Existing verified rows are not retroactively changed.
