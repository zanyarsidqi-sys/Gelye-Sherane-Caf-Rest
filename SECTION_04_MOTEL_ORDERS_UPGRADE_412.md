# Upgrade 412 — Credit Account Foundation

Adds locked-down schema for credit customers, credit accounts (IQD credit limits and outstanding balances), append-only-intended journal with idempotency keys, and barcode registry-to-account links. All tables have RLS enabled and client grants revoked. A permission-checked schema-status RPC reports readiness without exposing balances.

**Security boundary:** This is a *schema foundation*, not a functioning authoritative account service. No provisioning, verified ownership, consent, balance-check, posting, or debit RPC is provided. Database superusers can still mutate rows; journal immutability enforcement and tested transaction semantics must be implemented before real funds flow. Credit payments remain blocked.

Apply `20261010_412_credit_account_foundation.sql` in migration order. Flutter compilation and live Supabase testing not performed.
