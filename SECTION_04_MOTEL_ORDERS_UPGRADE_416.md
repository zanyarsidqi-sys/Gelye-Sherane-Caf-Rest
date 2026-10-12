# Upgrade 416 — Pending Credit Link Revocation

Adds a server-side, permission-gated way to revoke a **pending** barcode-account link with a mandatory reason and immutable-intended audit record. Outstanding evidence-review requests for the link are marked rejected with a revocation note. The Credit Identity Evidence Review screen provides a confirmation/reason dialog. Verified links cannot be revoked using this endpoint; no account balance, credit limit or payment is changed.

**Caveat:** This is a safe administrative rollback, not identity approval. The authoritative identity and consent provider is not connected; credit payments remain blocked. Migration and Flutter build require testing in a Supabase staging environment.
