# Dashboard Upgrade 132 — Stop provider transaction double-posting

**Concrete issue:** Upgrades 130–131 deduplicated by `provider_event_id` / inbox
ID. Providers can send *different* events about the **same** transaction,
so posting by inbox ID alone could double-credit a single payment.

Added a unique partial index on `(normalized provider, provider_reference)`
for server-verified inbox records. A second event claiming the same real
transaction now fails instead of becoming a second independently postable
record. Added a second unique index on unified-ledger provider event source
reference to enforce idempotency at the ledger itself. Existing duplicate
verified events or ledger postings cause the migration to fail closed;
finance must investigate and reconcile them before retrying.

**This is a real integrity fix**, not a new readiness function. No provider
webhook verification integration exists yet; a private backend must verify
provider signatures and query the provider's transaction API before using
Upgrade 130 or 131. Do not deploy without validating actual schema,
provider transaction ID semantics, and existing data in staging.

ZIP CRC validated. SQL not executed against Supabase.
