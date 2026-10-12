# Upgrade 444 — Provider Evidence Safety Inspection

Added a read-only permission-controlled Supabase RPC `gs_staff_credit_identity_evidence_safety` listing every external identity evidence submission for an onboarding request alongside its independent employee review. Every entry is explicitly flagged `provider_unverified` regardless of employee review outcome. This prevents manual references from being interpreted as authenticated external provider verification. The RPC validates that the onboarding request exists and requires Credit Management view permission. No verified customer binding, consent, or debit is created.

## Deployment
Apply migrations in order after review; verify against actual Supabase schema. No live migration or Flutter compilation was performed.
