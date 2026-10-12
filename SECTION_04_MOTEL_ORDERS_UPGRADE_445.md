# Upgrade 445 — External Evidence Safety UI

Added an Evidence Safety action to Credit Identity Onboarding. It calls the existing permission-gated `gs_staff_credit_identity_evidence_safety` RPC from Upgrade 444 and shows per-evidence provider, review outcome, submission time, and explicit provider-unverified status. Empty responses and RPC errors never imply approval. No customer identity activation, consent, or credit debit.

Flutter compilation and live Supabase testing were not available.
