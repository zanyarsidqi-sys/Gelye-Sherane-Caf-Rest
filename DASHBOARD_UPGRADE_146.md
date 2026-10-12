# Upgrade 146 — Executable PostgreSQL checkout security smoke test

Added `supabase/tests/mixed_checkout_security_smoke.sql`. Unlike the prior
Python source scanner, this script executes against an actual PostgreSQL
schema and fails on missing privileges, disabled guards or missing release
gating. It checks the feature gate, trusted backend function privileges,
RLS, attestation insert privileges, conflicting attestation triggers and
release gate. It runs inside a rolled-back transaction and changes no data.

Run against an **isolated staging Supabase database** after applying all
migrations: `psql -v ON_ERROR_STOP=1 "$STAGING_DATABASE_URL" -f
supabase/tests/mixed_checkout_security_smoke.sql`.

**Not executed here:** no staging database credentials were provided.
Passing does not prove webhook authenticity, order-level race safety,
financial correctness, or readiness to enable mixed checkout. The feature
gate remains disabled and the provider integration is still outstanding.
