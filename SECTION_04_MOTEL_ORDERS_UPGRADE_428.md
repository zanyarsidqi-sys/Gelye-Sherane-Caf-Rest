# Upgrade 428 — Credit Authorization Readiness Preflight

Added a read-only, permission-gated preflight RPC and employee **Readiness** button. It checks request expiry, evidence-review state, pending barcode/account link, account state, invoice status and exact amount. Customer authentication, customer consent and credit debit explicitly remain **not implemented/blocked**. This is not a consent mechanism and cannot move funds.

Flutter compilation and live Supabase migration execution have not been performed.
