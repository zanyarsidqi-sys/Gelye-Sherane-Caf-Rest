# Upgrade 139 — Mixed-payment security review and safeguards

Source review found two release-blocking risks:
1. A cash-only and mixed-payment attestation could coexist for one order.
   Added mutually exclusive, order-locking BEFORE INSERT triggers.
2. The mixed release RPC recomputed the approved provider amount but
   did not reject all extra ledger entries, unverified external evidence,
   owner offers or cash corrections. Hardened its release-time checks.

These safeguards are *source-level*, not live-tested. Existing deployment
requires a migration compatibility review and concurrency tests. The
mixed-release feature gate remains disabled. Provider-specific signed
webhook and API transaction verification are still not implemented.
