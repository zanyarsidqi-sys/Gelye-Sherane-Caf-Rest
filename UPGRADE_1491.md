# Upgrade 1491

- Shared feature across 35 sections: Reset local section workspace and verify access. Clears local search and shift handover marks, conceals section, starts a new permission generation. No financial writes.
- Added executable staging preflight SQL and guarded runner. Staging execution NOT performed; no staging connection was supplied.
- The crosswalk diagnostic is read-only and does not establish settlement authorization. No unified-ledger writes, invoice paid-state migration or certified IQD totals.
- Existing navigation, panels, footer, security and migration history retained. Rollback: restore Upgrade 1490 archive; database unchanged by this upgrade.
