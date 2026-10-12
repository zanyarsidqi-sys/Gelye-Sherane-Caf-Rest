# Upgrade 1342: Pending Payment source inspection

- Read-only, server-permission-checked listing of up to 200 posted motel finance invoices with `payment_status = unpaid`.
- Explicitly marks all invoice totals as source totals, not verified outstanding balances.
- Online classification and collection remain disabled; no payment mutation in this upgrade.
- Payments Management refreshes the source inspection alongside standing orders and financial diagnostics.
- Requires migration deployment; no Flutter SDK or live Supabase verification available.
