# Upgrade 371 — Invoice source reservations

Introduces a persistent source-order reservation registry, with unique food order and ledger IDs, and an audited staff identity. A permission-gated RPC validates the existing fingerprint-verified crosswalk before reserving charges. Calls are idempotent for unchanged approvals and reject changed reservations. It requires both Motel Orders and Invoices & Payments edit permissions.

**No official invoices, payment allocation, or ledger invoice links are created.** A subsequent transactional posting integration must validate the target official invoice schema and use these source IDs exactly once. The migration has not been executed against live Supabase and Flutter compilation has not been performed.
