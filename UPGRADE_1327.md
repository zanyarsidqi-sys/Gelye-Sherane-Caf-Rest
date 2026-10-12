# Upgrade 1327 — guarded live unpaid balance integration

- Dashboard Standing Cash and Pending Payment cards now independently request `gs_financial_live_unpaid_balances` with a 15-second timeout.
- Payments Management includes a live balance readout and refresh using the same RPC contract.
- Never treat cash-only reconciliations as comprehensive unpaid balances.
- Backend MUST implement the RPC with authenticated, permission-scoped access, tenant isolation, active occupied visit verification, source-tagged online/motel orders, all payment methods, prepaid motel allocations, cancellations and deduplication.
- The response MUST include `verified_complete: true` and nonnegative whole IQD fields `standing_cash_active_visits_iqd` and `pending_online_motel_unpaid_iqd`. Without a verified complete response, both values stay unavailable, NOT zero.
- This upgrade does NOT implement that backend RPC or claim live reporting is operational.
- Flutter compilation, integration and real device tests pending.
