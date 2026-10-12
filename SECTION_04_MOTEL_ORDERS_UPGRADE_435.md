# Upgrade 435 — Authenticated Customer Onboarding Acknowledgement

Added an authenticated-user-only, single-response onboarding acknowledgement or dispute RPC; read-only customer and staff history; a reusable Flutter customer acknowledgement panel; and a staff response viewer. Responses are bound to `auth.uid()` and the matching pending onboarding request. Database denies direct table writes. Acknowledgement is **not** verified identity, account ownership, consent for an invoice, or credit payment authorization. Customer panel is reusable but **not yet wired into a public customer route**; integrating authenticated customer navigation remains necessary. No credit debit or settlement is enabled.

Migration: `20261010_435_credit_identity_customer_acknowledgement.sql`. Flutter compilation and live Supabase migrations were not run.
