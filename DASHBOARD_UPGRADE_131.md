# Dashboard Upgrade 131 — Verified provider event ledger posting

Adds a real, server-only, idempotent ledger posting operation for card/online
payment events already independently verified and recorded in Upgrade 130.
Checks event/evidence consistency, order state, overpayment, and duplicate
source reference. Uses the existing unified ledger and preserves append-only
history. Updates ledger insert guard to allow ONLY matching verified events;
credit, owner waiver and refunds remain prohibited.

**Important security prerequisite:** Upgrade 130 is a trusted intake API,
not a provider verifier. A private backend must authenticate signed provider
webhooks and independently confirm transaction success via the provider API
before calling either RPC. Without that integration, no real provider event
can safely be posted. `p_posting_operator` is an accountable service operator,
not evidence of who made the payment.

**Limitations:** No provider integration credentials, refunds, partial
allocations, cash correction adjustments, checkout certification, or
multi-method release logic. All SQL remains untested against live Supabase.
