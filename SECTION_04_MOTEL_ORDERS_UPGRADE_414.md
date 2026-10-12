# Upgrade 414 — Two-person credit identity evidence review

Adds permission-gated evidence review requests for pending barcode-account links, with evidence references and mandatory notes. A **different employee** must record an evidence review or rejection; same-user decisions are rejected server-side. The Credit Management UI allows requests, review decisions and viewing recent history. Audit data includes both actors and timestamps.

**Important distinction:** An accepted *evidence review* is not authoritative customer identity verification. This upgrade intentionally never sets a customer as verified, never approves a barcode link, never activates a credit account, never assigns a credit limit, and never posts a debit. Real identity validation, customer consent and financial authorization require a future integration and verified tests.

Apply `supabase/migrations/20261010_414_credit_identity_review.sql` in migration order. No live database or Flutter compilation test was performed.
