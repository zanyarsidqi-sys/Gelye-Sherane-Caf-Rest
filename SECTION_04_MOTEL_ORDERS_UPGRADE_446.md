# Upgrade 446 — Latest External Evidence Guard

Added a permission-gated, read-only Supabase diagnostic that evaluates the **latest** external identity evidence submission and its corresponding independent review, rather than accidentally relying on an earlier reviewed submission. Reports customer dispute, onboarding state, missing/latest evidence, documentation-only review, and explicit blockers for provider verification, identity activation, consent, and credit debit.

This does not integrate an external provider or verify a customer. No credit payments are enabled. Supabase migrations and Flutter compilation have not been executed in a live environment.
