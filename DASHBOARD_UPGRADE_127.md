# Dashboard Upgrade 127 — Fix checkout of cancelled and transferred orders

A concrete security review of the existing cash-only checkout SQL found
that a **cancelled** order containing a valid cash-ledger mirror could
be excluded from checkout, even though its payment evidence still existed.
Also, transfer requests could be added after finance attestation and not
rechecked at release time.

**Changed the existing release RPC:**
- Rejects cancelled orders with **any** cash or ledger evidence, including
  valid cash mirrors, corrections, owner offers, transfer requests, external
  evidence, or settlement attestations.
- Rechecks table bill transfer request items against each active attested
  order at the moment of checkout.
- Preserves MFA, independent reviewer, amount snapshot, guest departure,
  cleaning, and shisha requirements.

This does **not** enable mixed-payment checkout. Before production:
verify the migration compiles against the deployed schema, test concurrent
transfer-request creation vs checkout, and confirm every legacy payment
writer is covered. ZIP integrity verified only; no database execution.
