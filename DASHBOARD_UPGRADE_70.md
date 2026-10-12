# Dashboard Upgrade 70 — Owner-only MFA Review Attestation

Added draft migration `20261009_070_owner_mfa_review_attestation_draft.sql`.

- Trusted database provisioning determines eligible owner accounts; employees
  cannot grant themselves owner privileges through a client RPC.
- Requires authenticated owner session with JWT AAL2 MFA.
- Locks the pending offer, validates linked order/visit and amount.
- Records one owner review per offer with immutable amount snapshot.
- Records owner actor, decision and time in protected audit storage.
- Rejection can change offer status to rejected.
- An owner approval records `approve_for_financial_review` ONLY.
  It does NOT mark the bill Owner Verified or waive any money.

Still required: fresh owner step-up (AAL2 alone does not prove recency),
a verified immutable ledger posting workflow, partial-item coverage checks,
payment reconciliation, owner UI, schema validation and production tests.
No Flutter compilation or Supabase deployment performed.
