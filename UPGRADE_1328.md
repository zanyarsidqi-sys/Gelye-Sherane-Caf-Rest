# Upgrade 1328: secured live financial reporting contract

- Inspected Supabase migration schemas for orders, items, cash payments, table visits, customer visit sessions, motel guest food requests, and motel invoice reconciliation.
- Installed the `gs_financial_live_unpaid_balances()` RPC contract with an authenticated, server-enforced `payments_management.can_view` check.
- Intentionally returns `verified_complete=false` and null amounts because cash-only reconciliation cannot certify all payment methods, prepaid motel packages, transfers, refunds, or cross-source duplication.
- Dashboard and Payments Management continue to reject incomplete responses and show unavailable rather than fabricated zeros.
- No other existing files changed; deployment of this SQL migration is required before the RPC exists in Supabase.
- Not tested against live Supabase; Flutter compilation and PostgreSQL migration execution remain pending.
