# Dashboard Upgrade 88 — Fail-closed ledger provenance guard

Added a draft **BEFORE INSERT** trigger for the unified payment ledger.

- Requires a recorded posting actor and nonempty payment source/reference.
- Rejects future verification/posting timestamps and verification later than posting.
- Explicitly rejects new **owner waivers**, **card/online/credit payments**,
  and **refunds/reversals** until their trusted approval, verification and
  posting workflows exist. This is intentional fail-closed behavior.
- Does not alter existing ledger records or grant clients insert privileges.
- Preserves the prior cumulative-reversal guard for any future approved design.

**Limitations:** This does not verify that cash was actually received; a
trusted writer could still supply untrue metadata. The external provider
integration, financial settlement, owner waivers and bill transfers remain
unimplemented. Review existing cash backfill workflows before staging
migration. No PostgreSQL/Flutter execution tests were performed.
