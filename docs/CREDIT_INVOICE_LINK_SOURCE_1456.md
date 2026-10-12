# Upgrade 1456 — Credit invoice linkage source integrity

This migration replaces only the existing credit-charge-to-invoice trigger function.
It independently validates pending credit request, active barcode registry, verified account link,
matching active IQD account, verified customer, reconciled invoice lines, and competing drafts.
It preserves the existing invoice row lock, unique constraints, cash collision prevention,
append-only journal and link immutability.

## Deployment gates
1. Back up staging and confirm prior migrations through 1455 are applied.
2. Inspect historical charges and links for incompatible data before applying this migration.
3. Apply this migration in a staging transaction; check dependencies and privileges.
4. Test authenticated posting, unauthorized denial, same-key retries, different-key retries,
   two simultaneous requests on the same invoice, and rollback on trigger failure.
5. Test barcode suspension, link revocation, account freeze, identity mismatch, invoice-line
   tampering, competing drafts, and cash collision.
6. Do not expose settlement controls or IQD totals until end-to-end verified.

No live staging execution was performed when this package was generated.
