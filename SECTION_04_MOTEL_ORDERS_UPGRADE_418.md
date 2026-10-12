# Upgrade 418 — Stale Credit Identity Review Protection

The evidence-decision RPC now locks the barcode-account link before the review record, checks the link is still pending, verifies account identity matches the review, and ensures the account is still pending. This prevents accepting stale evidence after link revocation or changes. Independent reviewer enforcement and the non-financial nature of evidence review are preserved.

Requires migration `20261010_418_credit_review_stale_link_guard.sql`. This does **not** verify ownership, activate credit, change balances or permit debit. Flutter compilation and live Supabase tests not run.
