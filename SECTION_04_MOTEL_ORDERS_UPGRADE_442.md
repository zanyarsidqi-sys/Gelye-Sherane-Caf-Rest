# Upgrade 442 — External identity readiness diagnostics

Added `gs_staff_credit_external_identity_readiness` as a permission-gated, read-only diagnostic of onboarding, disputes, independent assessment, external evidence, and review outcome. Explicitly reports provider verification as **not integrated** and identity activation, customer payment consent, and credit debit as **blocked**. This does not create a verified identity binding.

Flutter and live Supabase migrations have not been tested.
