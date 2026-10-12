# Upgrade 325 — Customer bill → cashier request integration

The QR bill preview now links to the existing visit-authorized customer assistance workflow, preselecting **Cashier** and a bill-review note. It does **not** calculate or claim a payable balance. The existing RPC enforces session validity, duplicate active requests, and rate limits. The customer can track the request in the same assistance screen.

CustomerCallEmployeeScreen accepts optional `initialType` and `initialNote`, retaining `waiter` as the default for existing callers. No new Supabase schema is required.

Validation: ZIP integrity and source checks only. Flutter compilation and live Supabase execution were not available. The gross bill still needs reconciliation against payment, discount, refund and transfer ledgers before any payable balance can be shown.
