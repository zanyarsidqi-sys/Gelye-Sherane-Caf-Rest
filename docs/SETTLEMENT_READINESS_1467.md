# Upgrade 1467 — Settlement readiness and staging checks

- Added read-only invoice readiness RPC; never marks invoice paid or certifies IQD balances.
- Reports explicit blockers for unverified invoice source, absent payment evidence, or method collisions.
- Even with one confirmed method, crosswalk/unified ledger remain blocked until independently proven.
- Run diagnostics/settlement_staging_1467.sql after deploying migrations in staging.
- Requires authorized staging auth to test invoice-specific responses.
- Provider receipt ingestion, crosswalk certification and atomic ledger settlement are NOT implemented by this upgrade.
