# Upgrade 1473: Explicit motel-to-cafe identity evidence

Adds an append-only, one-to-one identity evidence table and authorized registration RPC.
The finance employee must independently establish the **real** invoice UUID, real cafe order bigint ID, and durable evidence reference/description. The function validates existence and prevents reassignments, but **does not independently prove the supplied evidence is truthful**. Require second-person review of source documents before relying on mappings for settlement. No guessed identity conversion, no invoice paid-state change, no unified ledger write, no IQD certification.

Staging: apply migrations in order, run diagnostics/identity_staging_1473.sql using a real PostgreSQL staging connection; run the commented transaction test with real test identities and rollback. The SQL was NOT run during packaging because no live staging credentials were available. Before deployment, validate actual `gs_orders` schema and employee permissions. Rollback: disable EXECUTE on RPC first; preserve append-only evidence for audit; restore prior database snapshot only under approved migration procedures. Never delete financial evidence casually.
