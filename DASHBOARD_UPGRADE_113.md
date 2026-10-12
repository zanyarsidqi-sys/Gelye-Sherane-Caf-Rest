# Upgrade 113 — Actual cash-only settlement attestation

Instead of another read-only gate, this migration introduces an immutable
financial **attestation write** for a narrowly defined **cash-only** table
order. An independently provisioned finance reviewer with AAL2 MFA must
confirm the exact cash receipts against the order amount. It locks the order,
rejects any external/credit/owner-waiver evidence, any ledger entries, any
cash corrections, any transfer requests and any self-collected cash receipts.
The successful operation records an immutable attestation and audit event.

**Limits:** It does not prove cash is in the safe, support mixed-method
payments, alter the existing always-false checkout gates, or release tables.
Attestations must be invalidated/blocked against later order modifications
before they can safely authorize checkout. Do not enable automatic table
release based solely on this record. No database deployment/runtime test.
