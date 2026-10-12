# Upgrade 443 — External Identity Verification Readiness UI

Added **External Verification Readiness** to the employee Customer Identity Onboarding panel. The button calls the permission-gated read-only RPC introduced in Upgrade 442 and displays onboarding, dispute, independent assessment, evidence, independent review, provider integration, identity activation, customer consent and debit status. It fails closed when the RPC is unavailable and never marks an identity verified. No customer consent or credit charge is enabled.

Flutter build and live Supabase deployment have not been tested.
