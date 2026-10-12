# Dashboard Upgrade 124 — Refresh dashboard immediately after checkout

Fixed a real user-facing integration defect: after a successful server-side
cash-only table release, the Dashboard kept displaying a stale table-details
route and explicitly asked the employee to refresh manually. The release
component now notifies its parent after the server RPC **succeeds**. The
Dashboard closes the stale details route and fetches a fresh server snapshot.

- No optimistic release: callback is invoked only after successful RPC.
- On server rejection, the detail remains open and table is not marked free.
- No new approval, finance diagnostics or checkout SQL were added.
- Does not enable mixed/credit/provider checkout.

Static code and ZIP checks only; Flutter compilation and Supabase execution
are still pending.
