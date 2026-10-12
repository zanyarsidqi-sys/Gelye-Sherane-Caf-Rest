# Dashboard Upgrade 134 — Protect approved mixed-payment orders

**Actual integration change:** Upgrade 133 added immutable finance attestations
for orders paid using cash plus server-verified electronic payments. The
existing Upgrade 114 and 128 guards protected **only cash-only** attestations.
This left approved mixed-payment orders vulnerable to subsequent item, order,
receipt, ledger, correction, external evidence, owner-offer, and transfer
request changes.

Upgrade 134 replaces the two **existing trigger functions**, so the already
installed mutation and transfer-request triggers protect **both** cash-only
and mixed-payment attestations. The existing parent-order row locking remains
in effect to coordinate with finance approval.

**Not yet implemented:** mixed-payment table release, credit settlement,
provider webhook/API integration, refund processing. A finance attestation
is not permission to release a table. SQL has not been deployed or executed
against a Supabase database; test triggers and concurrent writes in staging.
