# Upgrade 565 — Replacement request idempotency

Adds a client-generated UUID per confirmed replacement, a transactionally committed server ledger, duplicate-request serialization, argument matching, and authenticated actor-scoped outcome lookup. The prior 8-argument endpoint is revoked for clients. Failed transactions roll back their ledger entries; successful transactions and their result are committed together. The Flutter UI queries the request ledger after uncertain transport failures without automatically repeating the mutation.

**Verification:** ZIP integrity and static checks only; Flutter compilation and live Supabase tests were not available. Deploy the SQL migration before the Flutter build.
