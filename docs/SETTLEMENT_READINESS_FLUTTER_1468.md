# Upgrade 1468: read-only invoice settlement readiness in Payments Management

Adds a real Flutter employee action to inspect an authoritative motel finance invoice UUID, call the existing permission-scoped settlement-readiness RPC, validate fail-closed response fields, and display source and payment-evidence blockers. The action is visible beside the Standing Cash/Pending Payment lists. No payment is posted or certified.

The SQL staging smoke script verifies existence, execute grants, receipt RLS, and inability of authenticated clients to forge receipts. Run against isolated staging after applying all migrations. This script is NOT a transactional payment test and has not been run against live PostgreSQL here.

**Provider receipt ingestion, verified cafe/motel crosswalk, invoice-paid/unified-ledger posting, and complete totals remain outstanding.**

Rollback: revert only the Flutter edit to the prior ZIP and omit this staging-only smoke script. Existing migrations and data are unchanged.
