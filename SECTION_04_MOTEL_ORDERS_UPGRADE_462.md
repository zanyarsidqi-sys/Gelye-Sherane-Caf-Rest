# Upgrade 462 — Customer authorization request visibility (read-only)

- Added authenticated customer RPC for invoice authorization requests, gated on a verified customer auth binding and absence of historical identity safety holds.
- No arbitrary customer ID parameter; invoice details not visible to pending or unverified identities.
- Added customer UI button to view requests and clear unverified-identity explanation.
- No approval, consent, payment or debit endpoint. Identity binding activation remains blocked pending independent authoritative verification.
- Requires applying the migration and Flutter build/test; neither was performed in this environment.
