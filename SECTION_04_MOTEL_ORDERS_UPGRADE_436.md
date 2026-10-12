# Upgrade 436 — Customer Dispute Safeguard

The independent employee evidence-review RPC now rejects further evidence submissions after the authenticated customer disputes their onboarding request. A read-only permission-protected dispute-status RPC reports why a review is blocked, and the staff panel includes a status dialog method. No identity is verified, no customer invoice consent is collected, and no credit payment can be posted.

Migration: `20261010_436_credit_identity_dispute_guard.sql`. Flutter compilation and live Supabase deployment were not performed.
