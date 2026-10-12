# Upgrade 434 — Independent Identity Evidence Review

Adds an append-only, permission-gated employee evidence review workflow for pending credit identity onboarding requests. The reviewer must be different from the onboarding requester. Reviews capture evidence reference, outcome, notes, employee ID and timestamp. Staff UI supports submitting reviews and viewing their history.

**Security boundary:** An `evidence_reviewed` outcome does not verify customer ownership, create a verified auth binding, constitute customer consent, or enable any credit debit. Verified customer identity requires a separate authenticated proof and approval mechanism not yet built. Flutter compilation and live Supabase migration testing not performed.
